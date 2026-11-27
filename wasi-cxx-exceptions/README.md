# C++ targets do not link for WASI unless built with `-fno-exceptions`

A SwiftPM package with an ordinary C++ target (no `throw` of its own, only `std::string` and `std::vector`) fails to link with the Swift SDK for WebAssembly: `undefined symbol: __cxa_throw`. Adding `-Xcxx -fno-exceptions` to the build fixes it.

- Upstream issue: not filed yet
- Upstream PR: none
- Status: reproducer ready; workaround known (`-Xcxx -fno-exceptions`)
- Affects: swift.org's Swift SDKs for WebAssembly (`wasm32-unknown-wasip1`), checked with 6.4.0 on macOS and 6.4.2 and 6.3.3 on Linux. Not compiler-specific: the C++ flags come from the SDK's toolset.

## Problem

clang compiles C++ with exceptions on by default. libc++'s inline helpers then throw (for example `std::length_error` when a `vector` or `string` would grow past `max_size()`), so plain container code references `__cxa_allocate_exception` and `__cxa_throw`. The SDK's libc++abi is built without exception support and does not define them, and the SDK's toolset does not turn exceptions off for C++:

    wasm-ld: error: .../words.cpp.o: undefined symbol: __cxa_allocate_exception
    wasm-ld: error: .../words.cpp.o: undefined symbol: __cxa_throw

The SDK's own C++ is built with `-fno-exceptions` (libc++, libc++abi, and since swiftlang/swift#92171 the Concurrency runtime), so the same flag for user code matches what the SDK ships.

## Reproduce

Needs a Swift toolchain and a matching Swift SDK for WebAssembly (`swift sdk install`, see swift.org). Optionally a WebAssembly runtime to run the module: [wasmtime](https://wasmtime.dev) 36 (the LTS release; releases from 48 on cannot run modules built for `wasm32-unknown-wasip1-threads`), or any runtime through `WASM_RUNTIME`.

    ./run.sh
    SWIFT_SDK=swift-6.4.2-RELEASE_wasm ./run.sh
    SWIFT=/path/to/usr/bin/swift WASM_RUNTIME="wasmtime run" ./run.sh

`Sources/Words/words.cpp` splits a string into a `std::vector<std::string>`; `Sources/repro/main.swift` calls it through the C header and prints the count. `run.sh` builds the package with `swift build --swift-sdk`, once as is and once with `-Xcxx -fno-exceptions`, and runs the build that linked if a runtime is available.

Expected: exit 0. The plain build links, and the program prints `words: 3`.

Actual (affected SDKs): exit 1. The plain build fails with the undefined symbols above; the build with `-Xcxx -fno-exceptions` links and prints `words: 3`.

## Fix

Pass `-fno-exceptions` to C++ in the SDK's toolset (`toolset.json`, `cxxCompiler.extraCLIOptions`); the toolset is written by swift-sdk-generator (`WebAssemblyRecipe.swift`). C++ code that uses `throw` or `try` then fails to compile with clang's "cannot use 'throw' with exceptions disabled" instead of failing to link. Our WASI threads SDK does this since [swifthost-sdk-wasip1-threads-6.4.2-7](https://github.com/Hyp3rSon1X/swift-toolchains/releases/tag/swifthost-sdk-wasip1-threads-6.4.2-7).

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` on Linux x86_64. `ci-setup.sh` installs the Swift SDK for WebAssembly that belongs to each job and wasmtime 36:

- official Swift 6.4.2 image with swift.org's 6.4.2 SDK for WebAssembly: the bug reproduces, so this job fails (expected);
- official Swift 6.4.2 image with an SDK whose toolset passes `-fno-exceptions` to C++ ([swifthost-sdk-wasip1-threads-6.4.2-7](https://github.com/Hyp3rSon1X/swift-toolchains/releases/tag/swifthost-sdk-wasip1-threads-6.4.2-7); `wasm32-unknown-wasip1-threads`, built with tail calls, and it carries other fixes too): the script passes;
- official Swift 6.3.3 image with swift.org's 6.3.3 SDK: informational.

The nightly `main` job is skipped (`ci.json`): the nightly image has no matching SDK for WebAssembly.
