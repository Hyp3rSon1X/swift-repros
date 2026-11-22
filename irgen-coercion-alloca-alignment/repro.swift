// A synthesized Hashable enum with a 16-byte aligned payload.
// The hashValue getter copies `self` out of a temporary that is only 8-byte aligned.
enum Value: Hashable {
  case small(UInt32)
  case wide(SIMD4<Float>, UInt8)
}

let v = Value.wide(SIMD4<Float>(1, 2, 3, 4), 64)
print(v.hashValue == Value.wide(SIMD4<Float>(1, 2, 3, 4), 64).hashValue)
