# `_swift_stdlib_immortalize` has the wrong signature on WebAssembly

Code that calls `_swift_stdlib_immortalize` through its SwiftShims declaration does not link cleanly for WebAssembly: wasm-ld reports `function signature mismatch`, and the call traps at run time. swift-collections 1.7.6 makes such a call from inlinable code, so every program that uses its `Deque` is affected.

- Upstream issue: not filed yet
- Upstream PR: not filed yet
- Status: fix ready, not proposed upstream yet
- Affects: every Swift SDK for WebAssembly we tried (swift.org 6.3.3 and 6.4.2); the code is unchanged on `main`. Other platforms are not affected.

## Problem

`RuntimeShims.h` declares `void _swift_stdlib_immortalize(void *obj)` as a plain C function. The runtime (`stdlib/public/runtime/RefCount.cpp`) defines it with `SWIFT_CC(swift)`. On most targets both conventions produce the same code for this signature. On WebAssembly, a swiftcc function gets two extra parameters (`swiftself`, `swifterror`), so the definition has the type `(i32, i32, i32) -> ()`, while a caller that uses the header calls `(i32) -> ()`:

    wasm-ld: warning: function signature mismatch: _swift_stdlib_immortalize
    >>> defined as (i32) -> void in main.o
    >>> defined as (i32, i32, i32) -> void in libswiftCore.a(RefCount.cpp.o)

With `-Xlinker --fatal-warnings` the link fails. Without it, wasm-ld replaces the call with a trap:

    0:  0x1184f - repro.wasm!signature_mismatch:_swift_stdlib_immortalize
    1:  0x11b5e - repro.wasm!main
    ...
    2: wasm trap: wasm `unreachable` instruction executed

swift-collections 1.7.6 calls the function from `@inlinable @_alwaysEmitIntoClient` code (`Sources/InternalCollectionsUtilities/Immortalize.swift`, used for the empty `Deque` storage), so the call is compiled into the client.

## Reproduce

Needs a Swift toolchain and a matching Swift SDK for WebAssembly (`swift sdk install`, see swift.org). Optionally a WebAssembly runtime to run the module: [wasmtime](https://wasmtime.dev) 36 (the LTS release; releases from 48 on cannot run modules built for `wasm32-unknown-wasip1-threads`), or any runtime through `WASM_RUNTIME`.

    ./run.sh
    SWIFT_SDK=swift-6.4.2-RELEASE_wasm ./run.sh
    SWIFT=/path/to/usr/bin/swift WASM_RUNTIME="wasmtime run" ./run.sh

`Sources/repro/main.swift` calls the function through `import SwiftShims`, releases the object ten times without retaining it, and prints the deinit count. `run.sh` builds it with `swift build --swift-sdk`, once with `-Xlinker --fatal-warnings` and once without, and runs the second build if a runtime is available.

Expected: exit 0. Both links succeed without warnings, and the program prints `deinit count: 0`.

Actual (affected SDKs): exit 1. The `--fatal-warnings` link fails with the message above, and the program traps at the call.

## Fix

The runtime defines `_swift_stdlib_immortalize` without `SWIFT_CC(swift)`, matching the header, and `RefCount.cpp` includes `RuntimeShims.h` so the compiler rejects any future disagreement. The symbol name does not change. Branch: https://github.com/Hyp3rSon1X/swift/tree/wasm-immortalize-signature. The upstream PR will be linked here once it is filed.

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` on Linux x86_64. `ci-setup.sh` installs the Swift SDK for WebAssembly that belongs to each job and wasmtime 36:

- official Swift 6.4.2 image with swift.org's 6.4.2 SDK for WebAssembly: the bug reproduces, so this job fails (expected);
- official Swift 6.4.2 image with an SDK whose runtime has the fix ([swifthost-sdk-wasip1-threads-6.4.2-5](https://github.com/Hyp3rSon1X/swift-toolchains/releases/tag/swifthost-sdk-wasip1-threads-6.4.2-5); `wasm32-unknown-wasip1-threads`, built with tail calls, and it carries other fixes too): the script passes;
- official Swift 6.3.3 image with swift.org's 6.3.3 SDK: informational.

The nightly `main` job is skipped (`ci.json`): the nightly image has no matching SDK for WebAssembly.

Verified run: https://github.com/Hyp3rSon1X/swift-repros/actions/runs/45354722133 (2026-11-24): the 6.4.2 and 6.3.3 jobs reproduce the bug (link error, then the trap), the job with the fixed SDK passes. Run logs expire after 90 days; the weekly runs keep the workflow page current.
