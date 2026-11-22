#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
swiftc="${SWIFTC:-swiftc}"
command -v "$swiftc" >/dev/null 2>&1 || { echo "setup: compiler not found: $swiftc"; exit 2; }
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

echo "compiler: $("$swiftc" --version 2>&1 | head -1)"

# IR check: a memcpy that claims 16-byte alignment for its source must not read
# from a coercion temporary that was allocated with a smaller alignment.
# On macOS the IR is generated for x86_64; elsewhere for the host target.
target=()
[ "$(uname -s)" = Darwin ] && target=(-target x86_64-apple-macos13)
if ! "$swiftc" "${target[@]}" -Onone -emit-ir "$here/repro.swift" -o "$work/repro.ll" 2>"$work/ir.err"; then
  echo "setup: -emit-ir failed"; head -5 "$work/ir.err"; exit 2
fi
bad="$(awk '
  /^define /  { delete al }
  /^ +%temp-coercion[A-Za-z0-9_.]* = alloca / {
    n = $1; a = $0; sub(/.*, align /, "", a); al[n] = a + 0
  }
  /call void @llvm.memcpy/ && match($0, /ptr align 16 %temp-coercion[A-Za-z0-9_.]*/) {
    s = substr($0, RSTART, RLENGTH); sub(/.*align 16 /, "", s)
    if ((s in al) && al[s] < 16) print s " is align " al[s] " but is copied as align 16"
  }' "$work/repro.ll")"
if [ -z "$bad" ]; then
  echo "check 1 (IR, -Onone): ok, coercion temporaries are aligned"
  ir_ok=1
else
  echo "check 1 (IR, -Onone): BUG, $bad"
  ir_ok=0
fi

# Run check: the misaligned load only faults on x86_64 hardware (not under Rosetta).
run_ok=1
if [ "$(uname -m)" = x86_64 ]; then
  if "$swiftc" -Onone "$here/repro.swift" -o "$work/repro" 2>"$work/build.err"; then
    out="$("$work/repro" 2>&1)"; rc=$?
    if [ "$rc" = 0 ] && [ "$out" = true ]; then
      echo "check 2 (run, -Onone): ok, printed 'true'"
    else
      echo "check 2 (run, -Onone): BUG, exit status $rc, output '$out'"; run_ok=0
    fi
  else
    echo "setup: build failed"; head -5 "$work/build.err"; exit 2
  fi
else
  echo "check 2 (run, -Onone): skipped, host is $(uname -m), not x86_64"
fi

[ "$ir_ok" = 1 ] && [ "$run_ok" = 1 ] && { echo "result: toolchain behaves correctly"; exit 0; }
echo "result: bug reproduced"; exit 1
