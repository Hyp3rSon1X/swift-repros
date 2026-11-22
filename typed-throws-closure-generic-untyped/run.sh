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

echo "compiler: $("$swiftc" --version 2>&1 | head -1)"

# The program only needs to compile; the bug is a compiler crash in IR generation.
status=0
for mode in "-emit-ir" "-c"; do
  for ver in 5 6; do
    label="check (swiftc $mode -swift-version $ver)"
    # The group keeps the shell's own "Segmentation fault" notice out of the output.
    { "$swiftc" "$mode" -swift-version "$ver" "$here/repro.swift" -o "$work/out"; } 2>"$work/build.err"
    rc=$?
    if [ "$rc" = 0 ]; then
      echo "$label: ok, compiled"
    elif [ "$rc" -ge 128 ] || grep -q -E 'Stack dump|Assertion|Please submit a bug report' "$work/build.err"; then
      echo "$label: BUG, compiler crashed (exit status $rc)"; show "$work/build.err" 30; status=1
    else
      echo "setup: unexpected compile error"; head -5 "$work/build.err"; exit 2
    fi
  done
done

[ "$status" = 0 ] && echo "result: toolchain behaves correctly" || echo "result: bug reproduced"
exit "$status"
