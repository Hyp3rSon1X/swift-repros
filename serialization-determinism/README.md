# Two kinds of `.swiftmodule` are not reproducible

Building the same module twice from the same inputs gives different `.swiftmodule` bytes when the module contains differentiability witnesses (for example `_Differentiation` itself), and for every Embedded Swift module whose inlined functions were removed. Build caches and reproducible-build checks see a changed module on every build.

- Upstream issue: none (the PR describes the problem)
- Upstream PR: not filed yet
- Status: fix ready, not proposed upstream yet
- Affects: Swift 6.3.3, 6.4.0, 6.4.2 and nightly `main` (6.5-dev, 2026-11) on macOS arm64 and Linux x86_64. Host-independent.

## Problem

`SILSerializer` (`lib/Serialization/SerializeSIL.cpp`) keeps two work lists in a `DenseSet` of pointers and writes them in iteration order, which depends on heap addresses:

- `DifferentiabilityWitnessesToEmit`: the `SIL_DIFFERENTIABILITY_WITNESS` records, the functions they reference and the IDs given to them come out in a different order in each compiler process.
- `FuncsToEmitDebug`: functions that only debug scopes refer to (functions that were inlined and then removed) are written as declarations in a different order. Embedded Swift serializes debug info for its modules (on `main` for every Embedded module, in 6.4.x for all but the standard library), so this hits any Embedded module with inlined code.

The module still works; only its bytes change.

## Reproduce

Needs a Swift toolchain (a swift.org toolchain on macOS, or Linux). On macOS set `SDKROOT` (for example `SDKROOT=$(xcrun --show-sdk-path)`). Check 1 is skipped when the toolchain has no `_Differentiation` module (Xcode's toolchain).

    ./run.sh
    SWIFTC=/path/to/swiftc RUNS=8 ./run.sh

`run.sh` builds each module `RUNS` times (default 4), each time in a new compiler process and output directory, and compares the `.swiftmodule` files:

1. `Witnesses.swift`: 16 `@inlinable @differentiable(reverse)` functions.
2. `Embedded.swift`: an Embedded module with 32 helpers inlined into `entry()`. It uses the Embedded standard library when the toolchain has one for the host, otherwise a `-parse-stdlib` variant with `-experimental-serialize-debug-info`. The script also checks that a client (`Client.swift`) sees the removed helpers through debug scopes; otherwise the check would prove nothing.

Expected: exit 0, every build of a module is byte-identical.

Actual (affected toolchains): exit 1, for example with swift.org 6.4.0 on macOS:

    check 1 (differentiability witnesses): BUG, 4 builds of the same input gave 4 different .swiftmodule files:
    check 2 (Embedded, Embedded standard library): BUG, 4 builds of the same input gave 4 different .swiftmodule files:
    check 2: a client sees 32 of the 32 inlined helpers through debug scopes

## Fix

Both work lists become `llvm::SetVector`s, so the records are written in insertion order, which follows the serializer's deterministic walk over the module. Two commits, one per list, each with a regression test that emits the module with `-enable-deterministic-check`. Branch: https://github.com/Hyp3rSon1X/swift/tree/serialization-determinism. A compiler with the change passes both checks (exit 0). The upstream PR will be linked here once it is filed.

## CI

[The workflow](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml) runs this directory's `run.sh` on Linux x86_64 with the official Swift 6.4.2 image (the bug reproduces, so this job fails, as expected), with the nightly `main` image and with Swift 6.3.3 (informational). There is no Linux image with the fix yet, so that job is skipped (`ci.json`).

Verified run: https://github.com/Hyp3rSon1X/swift-repros/actions/runs/45959361990 (2026-11-27): 6.3.3, 6.4.2 and nightly `main` reproduce both checks (4 builds, 4 different modules each; the client sees all 32 helpers). Run logs expire after 90 days; the weekly runs keep the workflow page current.
