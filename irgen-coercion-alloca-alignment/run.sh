#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
swiftc="${SWIFTC:-swiftc}"
command -v "$swiftc" >/dev/null 2>&1 || { echo "setup: compiler not found: $swiftc"; exit 2; }
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

# Indented excerpt of a log (the real compiler or program output), shown when a check fails.
show() { sed -n "1,${2:-40}p" "$1" | sed 's/^/    | /'; }
# Runs a built program with its output in $2 and returns its exit status. stdbuf (Linux) keeps the output
# printed before a crash; the braces keep the shell's own "Segmentation fault" notice out of the log.
run_prog() {
  if command -v stdbuf >/dev/null 2>&1; then { stdbuf -oL -eL "$1" >"$2" 2>&1; } 2>/dev/null
  else { "$1" >"$2" 2>&1; } 2>/dev/null; fi
}

echo "compiler: $("$swiftc" --version 2>&1 | head -1)"

# IR check: a memcpy that claims 16-byte alignment for its source must not read
# from a coercion temporary that was allocated with a smaller alignment.
# On macOS the IR is generated for x86_64; elsewhere for the host target.
target=()
[ "$(uname -s)" = Darwin ] && target=(-target x86_64-apple-macos13)
if ! "$swiftc" ${target[@]+"${target[@]}"} -Onone -emit-ir "$here/repro.swift" -o "$work/repro.ll" 2>"$work/ir.err"; then
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
  grep -n -E '%temp-coercion[A-Za-z0-9_.]* = alloca|memcpy.*%temp-coercion' "$work/repro.ll" > "$work/ir.lines"; show "$work/ir.lines" 12
  ir_ok=0
fi

# Run check: the misaligned load only faults on x86_64 hardware (not under Rosetta).
run_ok=1
if [ "$(uname -m)" = x86_64 ]; then
  if "$swiftc" -Onone "$here/repro.swift" -o "$work/repro" 2>"$work/build.err"; then
    run_prog "$work/repro" "$work/run.out"; rc=$?; out="$(cat "$work/run.out")"
    if [ "$rc" = 0 ] && [ "$out" = true ]; then
      echo "check 2 (run, -Onone): ok, printed 'true'"
    else
      echo "check 2 (run, -Onone): BUG, exit status $rc$([ "$rc" -gt 128 ] && echo " (signal $((rc-128)))"); program output:"; show "$work/run.out"; run_ok=0
    fi
  else
    echo "setup: build failed"; head -5 "$work/build.err"; exit 2
  fi
else
  echo "check 2 (run, -Onone): skipped, host is $(uname -m), not x86_64"
fi

[ "$ir_ok" = 1 ] && [ "$run_ok" = 1 ] && { echo "result: toolchain behaves correctly"; exit 0; }
echo "result: bug reproduced"; exit 1
