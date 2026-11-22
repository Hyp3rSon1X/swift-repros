# swift-repros

Minimal reproducers for Swift toolchain bugs that were reported or fixed upstream. Each directory holds a small Swift program and a `run.sh` that checks whether the toolchain in use is affected.

    cd <directory>
    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

`run.sh` uses `$SWIFTC` (default `swiftc`), builds in a temporary directory and removes it afterwards. It works on macOS and Linux and needs nothing beyond the toolchain. Exit codes:

- 0: the toolchain behaves correctly
- 1: the bug was reproduced
- 2: setup problem (for example the compiler was not found)

|Directory|Problem|Upstream issue|Status|
|-|-|-|-|
|`irgen-coercion-alloca-alignment`|Misaligned coercion temporary in IRGen; aligned load crashes on x86_64|[swiftlang/swift#93129](https://github.com/swiftlang/swift/issues/93129)|open, fix proposed|
|`silgen-isolation-nonsending-overrelease`|`#isolation` in a `nonisolated(nonsending)` function over-releases the calling actor|[swiftlang/swift#92799](https://github.com/swiftlang/swift/issues/92799)|open, fix proposed|
|`typed-throws-closure-generic-untyped`|IRGen crash for a typed-throws closure passed to a generic untyped-throws parameter|[swiftlang/swift#92312](https://github.com/swiftlang/swift/issues/92312)|open, fix proposed|

Licensed under Apache-2.0.
