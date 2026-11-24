// Calls _swift_stdlib_immortalize through its SwiftShims (C) declaration, the way swift-collections 1.7.6 does
// from inlinable code that is compiled into every client (Sources/InternalCollectionsUtilities/Immortalize.swift).
import SwiftShims

var deinitCount = 0

final class Canary {
  deinit { deinitCount += 1 }
}

let object = Canary()
let unmanaged = Unmanaged.passUnretained(object)
_swift_stdlib_immortalize(unmanaged.toOpaque())
print("immortalized")

// Releases without a matching retain must not free an immortal object.
for _ in 0..<10 {
  unmanaged.release()
}
withExtendedLifetime(object) {}
print("deinit count: \(deinitCount)")
