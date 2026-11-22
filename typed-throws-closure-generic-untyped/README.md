# Compiler crash for a typed-throws closure passed to a generic untyped-throws parameter

`swift-frontend` 6.4 crashes during IR generation when a closure with an explicit `throws(E)` is passed to a generic parameter declared with untyped `throws`, for example the operation of `Task.init`, if `E` has stored properties.

Upstream issue: https://github.com/swiftlang/swift/issues/92312

Requirements: a Swift toolchain (macOS with Xcode or a swift.org toolchain, or Linux). Nothing is run; the program only has to compile.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. `repro.swift` compiles with `-emit-ir` and `-c`, in Swift 5 and Swift 6 mode.

Actual (affected toolchains): exit 1. The compiler crashes (segmentation fault) in all four configurations.
