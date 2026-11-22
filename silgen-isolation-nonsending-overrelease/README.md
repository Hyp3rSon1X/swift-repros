# `#isolation` in a `nonisolated(nonsending)` function over-releases the calling actor

Passing `#isolation` to a consuming generic argument (such as `String(describing:)`) inside a `nonisolated(nonsending)` async function releases the caller's actor once too often, so the actor is deallocated while it is still running.

Upstream issue: https://github.com/swiftlang/swift/issues/92799

Requirements: a Swift 6 toolchain (macOS with Xcode or a swift.org toolchain, or Linux). The check builds the program at `-Onone` and `-O` and runs it.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. The program prints `end of test()`, then `Worker.deinit`, then `done`.

Actual (affected toolchains): exit 1. `Worker.deinit` runs during the first call and the program crashes with `EXC_BAD_ACCESS` / SIGSEGV. Compilers built with assertions instead reject the program with a SIL memory lifetime failure.
