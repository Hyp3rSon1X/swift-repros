# Misaligned coercion temporary in the synthesized `hashValue` of an enum

IRGen copies a value out of a coercion temporary that is allocated with 8-byte alignment but copied as 16-byte aligned, which crashes at `-Onone` on x86_64.

- Upstream issue: https://github.com/swiftlang/swift/issues/93129
- Upstream PR: not filed yet
- Status: open upstream; fix ready, PR not filed yet
- Affects: Swift 6.3.3, 6.4.x and main (nightly 6.5-dev, 2026-11); the crash needs an x86_64 target

## Problem

When a value is coerced from its native explosion, IRGen creates a temporary that is aligned only for the LLVM types of the coercion. Two peepholes in `visitStoreInst` forward that temporary and copy out of it with the alignment of the Swift type. Swift storage types are packed structs, so a type holding a 16-byte aligned `SIMD4<Float>` gets an 8-byte aligned temporary. At `-Onone`, x86_64 lowers the 16-byte aligned `memcpy` to `movaps`, which faults on the misaligned stack slot. Examples are an array literal of such structs and the synthesized `hashValue` of an enum with a `UInt128` payload.

## Reproduce

Needs a Swift toolchain (macOS with Xcode or a swift.org toolchain, or Linux). On macOS the IR is generated for x86_64 regardless of the host.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. The coercion alloca is at least 16-byte aligned, and on an x86_64 host the program prints `true`.

Actual (affected toolchains): exit 1. The IR check reports a `temp-coercion` alloca with `align 8` that is copied as `align 16`; on an x86_64 host the program also crashes with signal 11 (it does not fault on arm64 or under Rosetta).

## Fix

The forwarded alloca is raised to the alignment of the Swift type, as `adjustAllocaAlignment` already does for the coercion types, in the peepholes used by `visitStoreInst` (`isSafeForMemCpyPeephole`, `canForwardIndirectResultAlloca`). The change comes with an IRGen and an interpreter test. The fix will be linked here once the pull request is filed.

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` in three jobs on Linux x86_64:

- official Swift 6.4.2 release image: the bug reproduces, so this job fails (expected);
- Swift 6.4.2 with the fix: the script passes;
- nightly main: informational, shows whether the development toolchain is still affected.

Verified run: https://github.com/Hyp3rSon1X/swift-repros/actions/runs/45023684831 (2026-11-22). Run logs expire after 90 days; the weekly runs keep the workflow page current.
