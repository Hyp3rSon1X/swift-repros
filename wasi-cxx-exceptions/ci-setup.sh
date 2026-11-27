#!/usr/bin/env bash
# CI only (run by .github/workflows/repros.yml before run.sh, inside the toolchain's container): installs the
# Swift SDK for WebAssembly that belongs to $TOOLCHAIN, and wasmtime to run the module.
set -euo pipefail

case "$TOOLCHAIN" in
  "swift 6.4.2 release")
    # swift.org's SDK; checksum as published on swift.org.
    url=https://download.swift.org/swift-6.4.2-release/wasm-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz
    sum=83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5 ;;
  "swift 6.4.2 with fix")
    # The same 6.4.2 compiler with an SDK whose toolset passes -fno-exceptions to C++ (wasm32-unknown-wasip1-threads,
    # built with tail calls; it carries other fixes too, see its release notes).
    url=https://github.com/Hyp3rSon1X/swift-toolchains/releases/download/swifthost-sdk-wasip1-threads-6.4.2-7/swift-6.4.2-RELEASE_wasm-threads-tailcall.artifactbundle.zip
    sum=55f6a3962e1f36db8d55dfaced0c46a12196767e2ede25ee939895b4dec3cfc5 ;;
  "swift 6.3.3 release")
    url=https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz
    sum=cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7 ;;
  *)
    echo "no Swift SDK for WebAssembly configured for toolchain: $TOOLCHAIN"; exit 2 ;;
esac

missing=()
for tool in curl xz unzip; do command -v "$tool" >/dev/null 2>&1 || missing+=("$tool"); done
if [ "${#missing[@]}" -gt 0 ]; then
  apt-get update -qq
  apt-get install -y -qq curl xz-utils unzip >/dev/null
fi

swift sdk install "$url" --checksum "$sum"
swift sdk list

# wasmtime 36 (LTS): later releases dropped wasi-threads, which threads modules need.
wt=wasmtime-v36.0.23-x86_64-linux
curl -sSfL -o "$RUNNER_TEMP/$wt.tar.xz" "https://github.com/bytecodealliance/wasmtime/releases/download/v36.0.23/$wt.tar.xz"
echo "f2887b12e6a53dd5c2b6649b99e39a4cbf242ee50f246e9cbd31baa32e80a835  $RUNNER_TEMP/$wt.tar.xz" | sha256sum -c -
tar -xJf "$RUNNER_TEMP/$wt.tar.xz" -C "$RUNNER_TEMP"
echo "$RUNNER_TEMP/$wt" >> "$GITHUB_PATH"
