# `#isolation` in a `nonisolated(nonsending)` function over-releases the calling actor

Passing `#isolation` to a consuming generic argument (such as `String(describing:)`) inside a `nonisolated(nonsending)` async function releases the caller's actor once too often, so the actor is deallocated while it is still running.

- Upstream issue: https://github.com/swiftlang/swift/issues/92799
- Upstream PR: not filed yet
- Status: open upstream; fix ready, PR not filed yet
- Affects: Swift 6.3.3, 6.4.x and main (nightly 6.5-dev, 2026-11)

## Problem

In a `nonisolated(nonsending)` function, `#isolation` is emitted as a cast of the implicit `@guaranteed` isolated parameter, and that borrowed value was returned as the expression's result regardless of the requested context. When the value was consumed, for example stored into an `@in` argument by `String(describing: #isolation)`, it was forwarded without a copy, so the callee released the caller's actor. `.some(#isolation)` was rejected by the ownership verifier, and compilers built with assertions report "store-borrow location cannot be written".

## Reproduce

Needs a Swift 6 toolchain (macOS with Xcode or a swift.org toolchain, or Linux). The check builds the program at `-Onone` and `-O` and runs it.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. The program prints `end of test()`, then `Worker.deinit`, then `done`.

Actual (affected toolchains): exit 1. `Worker.deinit` runs during the first call and the program crashes with `EXC_BAD_ACCESS` / SIGSEGV. Compilers built with assertions instead reject the program with a SIL memory lifetime failure.

## Fix

`RValueEmitter::visitCurrentContextIsolationExpr` in SILGen now copies the isolation value unless the context accepts a +0 value, as `emitExtractFunctionIsolation` does. The change comes with a SILGen test and an executable test. The fix will be linked here once the pull request is filed.

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` in three jobs on Linux x86_64:

- official Swift 6.4.2 release image: the bug reproduces, so this job fails (expected);
- Swift 6.4.2 with the fix: the script passes;
- nightly main: informational, shows whether the development toolchain is still affected.

Verified run: https://github.com/Hyp3rSon1X/swift-repros/actions/runs/45023684831 (2026-11-22). Run logs expire after 90 days; the weekly runs keep the workflow page current.
