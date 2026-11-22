# swift-repros

An open list of Swift toolchain problems we found and fixed: minimal reproducers for bugs that were reported or fixed upstream. Each directory holds a small Swift program and a `run.sh` that checks whether the toolchain in use is affected.

    cd <directory>
    ./run.sh
    SWIFTC=/path/to/swiftc ./run.sh

`run.sh` uses `$SWIFTC` (default `swiftc`), builds in a temporary directory and removes it afterwards. It works on macOS and Linux and needs nothing beyond the toolchain. Exit codes:

- 0: the toolchain behaves correctly
- 1: the bug was reproduced
- 2: setup problem (for example the compiler was not found)

## Proposed upstream

None yet.

## Open upstream, fix ready

|Directory|Problem|Upstream issue|Status|
|-|-|-|-|
|[`irgen-coercion-alloca-alignment`](irgen-coercion-alloca-alignment)|Misaligned coercion temporary in IRGen; aligned load crashes on x86_64|[swiftlang/swift#93129](https://github.com/swiftlang/swift/issues/93129)|open upstream; fix ready, PR not filed yet|
|[`silgen-isolation-nonsending-overrelease`](silgen-isolation-nonsending-overrelease)|`#isolation` in a `nonisolated(nonsending)` function over-releases the calling actor|[swiftlang/swift#92799](https://github.com/swiftlang/swift/issues/92799)|open upstream; fix ready, PR not filed yet|
|[`typed-throws-closure-generic-untyped`](typed-throws-closure-generic-untyped)|IRGen crash for a typed-throws closure passed to a generic untyped-throws parameter|[swiftlang/swift#92312](https://github.com/swiftlang/swift/issues/92312)|open upstream; fix ready, PR not filed yet|

## Upstreamed

None yet. Directories whose fix was merged upstream move to [`upstreamed/`](upstreamed). Issues and pull requests link commit-pinned paths, so moving a directory does not break those links.

## CI

[![repros](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml/badge.svg)](https://github.com/Hyp3rSon1X/swift-repros/actions/workflows/repros.yml)

GitHub Actions discovers every directory with a `run.sh` (top level and `upstreamed/`) and runs it on Linux x86_64 against four toolchains (listed in `.github/toolchains.json`), so the failure and the fix can be seen
on a real system:

- **swift 6.4.2 release** (official `swift:6.4.2-noble` image): the bug is expected to reproduce; that job fails,
  the run does not.
- **swift 6.4.2 with fix**: Swift 6.4.2 with backported fixes, including the ones proposed for these issues (it also
  carries other fixes, listed in its [release notes](https://github.com/Hyp3rSon1X/swift-toolchains/releases/tag/swift-6.4.2-hyp3r.7)); must pass.
- **nightly main** (official `swiftlang/swift:nightly-main-noble` image, which can lag `main` by a few weeks):
  informational; it shows whether the current development toolchain is still affected.
- **swift 6.3.3 release** (official `swift:6.3.3-noble` image): informational; it shows whether a bug is a
  regression in 6.4.

A directory can add a `ci.json` with `{"with_fix_image": "<image>"}` to use a different image for its with-fix job. The workflow runs on every push and weekly. Each job's summary shows the full output of `run.sh`.

Licensed under Apache-2.0.
