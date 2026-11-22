# Misaligned coercion temporary in the synthesized `hashValue` of an enum

At `-Onone`, IRGen copies a value out of a coercion temporary that is allocated with 8-byte alignment but copied as 16-byte aligned; on x86_64 this becomes an aligned `movaps` and the program crashes with SIGSEGV.

Upstream issue: https://github.com/swiftlang/swift/issues/93129

Requirements: a Swift toolchain (macOS with Xcode or a swift.org toolchain, or Linux). On macOS the IR is generated for x86_64 regardless of the host.

    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

Expected: exit 0. The coercion alloca is at least 16-byte aligned, and on an x86_64 host the program prints `true`.

Actual (affected toolchains): exit 1. The IR check reports a `temp-coercion` alloca with `align 8` that is copied as `align 16`; on an x86_64 host the program also crashes with signal 11 (it does not fault on arm64 or under Rosetta).
