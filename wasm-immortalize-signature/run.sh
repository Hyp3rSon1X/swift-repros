#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
#
# Needs a Swift toolchain and a matching Swift SDK for WebAssembly:
#   SWIFT_SDK        SDK id for `swift build --swift-sdk` (default: the only installed non-Embedded SDK whose id
#                    contains "wasm")
#   SWIFT_SDKS_PATH  optional, passed as --swift-sdks-path
#   SWIFT / SWIFTC   the toolchain's `swift` (or its `swiftc`, whose directory is used); default: `swift`
#   WASM_RUNTIME     optional command that runs a .wasm file; default: wasmtime, if installed
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${SWIFTC:-}" ]; then swift="$(dirname "$SWIFTC")/swift"; else swift="${SWIFT:-swift}"; fi
command -v "$swift" >/dev/null 2>&1 || { echo "setup: swift not found: $swift"; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/repro.XXXXXX")" || exit 2
trap 'rm -rf "$work"' EXIT

# Indented excerpt of a log (the real compiler, linker or program output), shown when a check fails.
show() { sed -n "1,${2:-40}p" "$1" | sed 's/^/    | /'; }

echo "compiler: $("$swift" --version 2>&1 | grep -m1 -i 'swift version')"

sdks=()
[ -n "${SWIFT_SDKS_PATH:-}" ] && sdks=(--swift-sdks-path "$SWIFT_SDKS_PATH")
sdk="${SWIFT_SDK:-}"
if [ -z "$sdk" ]; then
  found="$("$swift" sdk list ${sdks[@]+"${sdks[@]}"} 2>/dev/null | grep -i wasm | grep -v -i embedded)"
  if [ -n "$found" ] && [ "$(printf '%s\n' "$found" | wc -l)" -eq 1 ]; then
    sdk="$found"
  else
    echo "setup: set SWIFT_SDK to the id of an installed Swift SDK for WebAssembly (swift sdk list)"
    [ -n "$found" ] && printf '%s\n' "$found" | sed 's/^/    /'
    exit 2
  fi
fi
echo "swift sdk: $sdk"

cp -R "$here/Package.swift" "$here/Sources" "$work/"
build() {
  "$swift" build --package-path "$work" --scratch-path "$work/.build" --swift-sdk "$sdk" ${sdks[@]+"${sdks[@]}"} "$@"
}

status=0

# 1. The program calls _swift_stdlib_immortalize through the C declaration in SwiftShims. wasm-ld checks that
#    the caller's and the definition's function types agree; it only warns, so turn warnings into errors.
build -Xlinker --fatal-warnings >"$work/fatal.log" 2>&1
rc=$?
if grep -q 'signature mismatch: _swift_stdlib_immortalize' "$work/fatal.log"; then
  echo "check (link with --fatal-warnings): BUG, function signature mismatch"
  # First lines of the linker message, with paths shortened to file names.
  grep -A2 'signature mismatch' "$work/fatal.log" | head -3 | sed -E 's/^.*(wasm-ld: )/\1/; s#/[^ ]*/##g; s/^/    | /'
  status=1
elif [ "$rc" = 0 ]; then
  echo "check (link with --fatal-warnings): ok, linked without warnings"
else
  echo "setup: build failed"; show "$work/fatal.log" 30; exit 2
fi

# 2. Without --fatal-warnings the module links, and wasm-ld replaces the mismatched call with a trap.
build >"$work/plain.log" 2>&1 || { echo "setup: build failed"; show "$work/plain.log" 30; exit 2; }
wasm="$(build --show-bin-path 2>/dev/null)/repro.wasm"
[ -f "$wasm" ] || wasm="$(build --show-bin-path 2>/dev/null)/repro"
runtime="${WASM_RUNTIME:-}"
if [ -z "$runtime" ] && command -v wasmtime >/dev/null 2>&1; then
  # Threads flags so that modules built for wasm32-unknown-wasip1-threads run too (wasmtime 36 LTS has them;
  # releases from 48 on dropped wasi-threads).
  runtime="wasmtime run -W threads=y -S threads=y"
fi
if [ -z "$runtime" ]; then
  echo "check (run): skipped, no WebAssembly runtime (set WASM_RUNTIME or install wasmtime)"
else
  $runtime "$wasm" >"$work/run.log" 2>&1
  rc=$?
  if [ "$rc" = 0 ] && grep -q '^deinit count: 0$' "$work/run.log"; then
    echo "check (run): ok, the object stayed immortal"
  elif grep -q 'unreachable' "$work/run.log"; then
    echo "check (run): BUG, trapped (exit status $rc)"
    grep -E 'signature_mismatch|unreachable' "$work/run.log" | head -3 | sed 's/^ */    | /'; status=1
  elif [ "$rc" = 0 ]; then
    echo "check (run): BUG, the object was freed"; show "$work/run.log" 12; status=1
  else
    echo "setup: the WebAssembly runtime failed (exit status $rc)"; show "$work/run.log" 12; exit 2
  fi
fi

[ "$status" = 0 ] && echo "result: toolchain behaves correctly" || echo "result: bug reproduced"
exit "$status"
