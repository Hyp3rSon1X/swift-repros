#!/usr/bin/env bash
# Exit 0: toolchain is correct. Exit 1: bug reproduced. Exit 2: setup problem.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
swiftc="${SWIFTC:-swiftc}"
runs="${RUNS:-4}"
command -v "$swiftc" >/dev/null 2>&1 || { echo "setup: compiler not found: $swiftc"; exit 2; }
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

show() { sed -n "1,${2:-20}p" "$1" | sed 's/^/    | /'; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -c1-16; }

echo "compiler: $("$swiftc" --version 2>/dev/null | head -1)"

# emit <case> <swiftc arguments...>: builds module M $runs times, each in a fresh compiler process and output
# directory, from the same inputs. Prints one hash per build; returns 2 if a build fails (log in $work/<case>.err).
emit() {
  local name=$1; shift
  local i
  for i in $(seq 1 "$runs"); do
    mkdir -p "$work/$name/$i"
    "$swiftc" -emit-module -module-name M -o "$work/$name/$i/M.swiftmodule" "$@" >"$work/$name.err" 2>&1 || return 2
    sha "$work/$name/$i/M.swiftmodule"
  done
}

# report <case> <description> <hashes>: 0 if every build produced the same bytes, 1 otherwise.
report() {
  local distinct
  distinct=$(printf '%s\n' "$3" | sort -u | wc -l | tr -d ' ')
  if [ "$distinct" = 1 ]; then
    echo "$1 ($2): ok, $runs builds, identical .swiftmodule"
    return 0
  fi
  echo "$1 ($2): BUG, $runs builds of the same input gave $distinct different .swiftmodule files:"
  printf '%s\n' "$3" | sed 's/^/    | /'
  return 1
}

status=0 ran=0

# 1. Differentiability witnesses (any module with @differentiable functions, e.g. _Differentiation itself).
if hashes=$(emit witnesses -parse-as-library "$here/Witnesses.swift"); then
  ran=$((ran + 1))
  report "check 1" "differentiability witnesses" "$hashes" || status=1
elif grep -q "no such module '_Differentiation'" "$work/witnesses.err"; then
  echo "check 1 (differentiability witnesses): skipped, this toolchain has no _Differentiation module"
else
  echo "setup: check 1 failed to compile"; show "$work/witnesses.err"; exit 2
fi

# 2. Embedded Swift: debug info is serialized for every Embedded module that is not the standard library.
#    Uses the Embedded standard library when the toolchain has one for the host, otherwise -parse-stdlib.
embedded=(-enable-experimental-feature Embedded -wmo -O)
if hashes=$(emit embedded "${embedded[@]}" "$here/Embedded.swift"); then
  mode="Embedded standard library"
  client_flags=("${embedded[@]}")
else
  mode="-parse-stdlib"
  { echo 'public struct Int { var v: Builtin.Int64 }'
    sed -e 's/x &\* 3 &+ \([0-9]*\)/Int(v: Builtin.add_Int64(x.v, x.v))/' "$here/Embedded.swift"; } >"$work/EmbeddedNoStdlib.swift"
  client_flags=("${embedded[@]}" -parse-stdlib)
  hashes=$(emit embedded "${client_flags[@]}" -Xfrontend -experimental-serialize-debug-info "$work/EmbeddedNoStdlib.swift") || {
    echo "setup: check 2 failed to compile"; show "$work/embedded.err"; exit 2; }
fi
ran=$((ran + 1))
report "check 2" "Embedded, $mode" "$hashes" || status=1

# The check above proves something only if the module refers to the inlined helpers from debug scopes.
"$swiftc" -emit-sil -g -module-name Client -I "$work/embedded/1" "${client_flags[@]}" "$here/Client.swift" \
  >"$work/client.sil" 2>"$work/client.err" || { echo "setup: client -emit-sil failed"; show "$work/client.err"; exit 2; }
scopes=$(grep -c 'sil_scope .*parent @$e1M[0-9]*helper' "$work/client.sil")
echo "check 2: a client sees $scopes of the 32 inlined helpers through debug scopes"
[ "$scopes" -gt 0 ] || { echo "setup: no helper scopes in the client SIL, check 2 is not meaningful here"; exit 2; }

[ "$ran" -gt 0 ] || exit 2
exit "$status"
