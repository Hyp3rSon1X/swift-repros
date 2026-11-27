#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
#
# Needs a Swift toolchain and a matching Swift SDK for WebAssembly (WASI):
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

# Two copies so the two builds below do not share a build directory.
for v in plain noexc; do mkdir -p "$work/$v" && cp -R "$here/Package.swift" "$here/Sources" "$work/$v/"; done
build() {
  local v="$1"; shift
  "$swift" build --package-path "$work/$v" --scratch-path "$work/$v/.build" --swift-sdk "$sdk" \
    ${sdks[@]+"${sdks[@]}"} "$@"
}
undefined_cxa() { grep -oE 'undefined symbol: __cxa_[a-z_]+' "$1" | sort -u; }

status=0
linked=""

# 1. A plain build. The C++ target throws nothing itself, but libc++'s inline helpers (vector and string growth)
#    throw length_error when exceptions are on, which is clang's default for C++.
build plain >"$work/plain.log" 2>&1
rc=$?
if [ -n "$(undefined_cxa "$work/plain.log")" ]; then
  echo "check (build): BUG, the C++ target does not link"
  undefined_cxa "$work/plain.log" | sed 's/^/    | wasm-ld: error: ... /'
  status=1
elif [ "$rc" = 0 ]; then
  echo "check (build): ok, linked"
  linked=plain
else
  echo "setup: build failed"; show "$work/plain.log" 30; exit 2
fi

# 2. The same package built with exceptions off for C++ (what the SDK's own libc++ is built with).
build noexc -Xcxx -fno-exceptions >"$work/noexc.log" 2>&1
rc=$?
if [ "$rc" = 0 ]; then
  echo "check (build with -Xcxx -fno-exceptions): ok, linked"
  [ -z "$linked" ] && linked=noexc
elif [ -n "$(undefined_cxa "$work/noexc.log")" ]; then
  echo "check (build with -Xcxx -fno-exceptions): still undefined"
  undefined_cxa "$work/noexc.log" | sed 's/^/    | /'
else
  echo "setup: build with -Xcxx -fno-exceptions failed"; show "$work/noexc.log" 30; exit 2
fi

# 3. Run whichever build linked.
runtime="${WASM_RUNTIME:-}"
if [ -z "$runtime" ] && command -v wasmtime >/dev/null 2>&1; then
  # Threads flags so that modules built for wasm32-unknown-wasip1-threads run too (wasmtime 36 LTS has them;
  # releases from 48 on dropped wasi-threads).
  runtime="wasmtime run -W threads=y -S threads=y"
fi
if [ -z "$linked" ]; then
  echo "check (run): skipped, nothing linked"
elif [ -z "$runtime" ]; then
  echo "check (run): skipped, no WebAssembly runtime (set WASM_RUNTIME or install wasmtime)"
else
  bin="$(build "$linked" --show-bin-path 2>/dev/null)"
  wasm="$bin/repro.wasm"; [ -f "$wasm" ] || wasm="$bin/repro"
  $runtime "$wasm" >"$work/run.log" 2>&1
  rc=$?
  if [ "$rc" = 0 ] && grep -q '^words: 3$' "$work/run.log"; then
    echo "check (run, $linked build): ok, printed 'words: 3'"
  else
    echo "check (run, $linked build): unexpected result (exit status $rc)"; show "$work/run.log" 10; exit 2
  fi
fi

exit "$status"
