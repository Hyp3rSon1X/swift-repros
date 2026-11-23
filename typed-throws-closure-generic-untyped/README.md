# Compiler crash for a typed-throws closure passed to a generic untyped-throws parameter

`swift-frontend` crashes during IR generation when a closure with an explicit `throws(E)` is passed to a generic parameter declared with untyped `throws`, for example the operation of `Task.init`, if `E` has stored properties.

- Upstream issue: https://github.com/swiftlang/swift/issues/92312
- Upstream PR: https://github.com/swiftlang/swift/pull/94589
- Status: open upstream; fix proposed in swiftlang/swift#94589 (in review)
- Affects: Swift 6.4.x and main (nightly 6.5-dev, 2026-11); 6.3.3 is not affected (a 6.4 regression)

## Problem

For `generic { () async throws(E) -> Int in ... }`, SILGen emits the closure directly at the parameter's abstraction pattern, with a body that throws the type-erased `any Error`. When the pattern is generic, `getSubstFunctionTypePattern` first generalizes it but kept the concrete error type, so the closure was lowered with `@error E`. The body then threw an `any Error` value out of a function whose error result was `E`. That fails SIL verification; without assertions, IRGen crashes for error types with storage, and the error read back from `Task.result` is garbage for payload-less enums.

## Reproduce

Needs a Swift toolchain (macOS with Xcode or a swift.org toolchain, or Linux). Nothing is run; the program only has to compile.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. `repro.swift` compiles with `-emit-ir` and `-c`, in Swift 5 and Swift 6 mode.

Actual (affected toolchains): exit 1. The compiler crashes (segmentation fault) in all four configurations.

## Fix

`getSubstFunctionTypePattern` now applies the same type erasure of the thrown error that `getSILFunctionType` applies, so the closure is lowered with `@error any Error`. This also makes the reabstraction thunk around the closure unnecessary. The change comes with two SIL tests. The fix will be linked here once the pull request is filed.

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` in three jobs on Linux x86_64:

- official Swift 6.4.2 release image: the bug reproduces, so this job fails (expected);
- Swift 6.4.2 with the fix: the script passes;
- nightly main: informational, shows whether the development toolchain is still affected.

Verified run: https://github.com/Hyp3rSon1X/swift-repros/actions/runs/45023684831 (2026-11-22). Run logs expire after 90 days; the weekly runs keep the workflow page current.
