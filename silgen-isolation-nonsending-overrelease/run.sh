#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
swiftc="${SWIFTC:-swiftc}"
command -v "$swiftc" >/dev/null 2>&1 || { echo "setup: compiler not found: $swiftc"; exit 2; }
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

echo "compiler: $("$swiftc" --version 2>&1 | head -1)"

expected=$'1: Optional(Repro.Worker)\n2: Optional(Repro.Worker)\nend of test()\nWorker.deinit\ndone'
status=0
for opt in -Onone -O; do
  label="check (build and run, $opt)"
  # Assertion-enabled compilers reject the program with a SIL verifier failure.
  if ! "$swiftc" -swift-version 6 -module-name Repro "$opt" "$here/repro.swift" -o "$work/repro$opt" 2>"$work/build.err"; then
    if grep -q -E 'memory lifetime|store-borrow|Stack dump' "$work/build.err"; then
      echo "$label: BUG, the compiler fails on the program"; status=1
    else
      echo "setup: build failed"; head -5 "$work/build.err"; exit 2
    fi
    continue
  fi
  out="$("$work/repro$opt" 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$expected" ]; then
    echo "$label: ok, the actor is released once, after the last use"
  else
    echo "$label: BUG, exit status $rc, output: $(printf '%s' "$out" | tr '\n' '|')"; status=1
  fi
done

[ "$status" = 0 ] && echo "result: toolchain behaves correctly" || echo "result: bug reproduced"
exit "$status"
