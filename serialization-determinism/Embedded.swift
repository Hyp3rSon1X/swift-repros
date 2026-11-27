// An Embedded Swift module whose helpers are inlined into entry() and then
// removed, so its .swiftmodule refers to them only from debug scopes.

@inline(__always) func helper0(_ x: Int) -> Int { x &* 3 &+ 0 }
@inline(__always) func helper1(_ x: Int) -> Int { x &* 3 &+ 1 }
@inline(__always) func helper2(_ x: Int) -> Int { x &* 3 &+ 2 }
@inline(__always) func helper3(_ x: Int) -> Int { x &* 3 &+ 3 }
@inline(__always) func helper4(_ x: Int) -> Int { x &* 3 &+ 4 }
@inline(__always) func helper5(_ x: Int) -> Int { x &* 3 &+ 5 }
@inline(__always) func helper6(_ x: Int) -> Int { x &* 3 &+ 6 }
@inline(__always) func helper7(_ x: Int) -> Int { x &* 3 &+ 7 }
@inline(__always) func helper8(_ x: Int) -> Int { x &* 3 &+ 8 }
@inline(__always) func helper9(_ x: Int) -> Int { x &* 3 &+ 9 }
@inline(__always) func helper10(_ x: Int) -> Int { x &* 3 &+ 10 }
@inline(__always) func helper11(_ x: Int) -> Int { x &* 3 &+ 11 }
@inline(__always) func helper12(_ x: Int) -> Int { x &* 3 &+ 12 }
@inline(__always) func helper13(_ x: Int) -> Int { x &* 3 &+ 13 }
@inline(__always) func helper14(_ x: Int) -> Int { x &* 3 &+ 14 }
@inline(__always) func helper15(_ x: Int) -> Int { x &* 3 &+ 15 }
@inline(__always) func helper16(_ x: Int) -> Int { x &* 3 &+ 16 }
@inline(__always) func helper17(_ x: Int) -> Int { x &* 3 &+ 17 }
@inline(__always) func helper18(_ x: Int) -> Int { x &* 3 &+ 18 }
@inline(__always) func helper19(_ x: Int) -> Int { x &* 3 &+ 19 }
@inline(__always) func helper20(_ x: Int) -> Int { x &* 3 &+ 20 }
@inline(__always) func helper21(_ x: Int) -> Int { x &* 3 &+ 21 }
@inline(__always) func helper22(_ x: Int) -> Int { x &* 3 &+ 22 }
@inline(__always) func helper23(_ x: Int) -> Int { x &* 3 &+ 23 }
@inline(__always) func helper24(_ x: Int) -> Int { x &* 3 &+ 24 }
@inline(__always) func helper25(_ x: Int) -> Int { x &* 3 &+ 25 }
@inline(__always) func helper26(_ x: Int) -> Int { x &* 3 &+ 26 }
@inline(__always) func helper27(_ x: Int) -> Int { x &* 3 &+ 27 }
@inline(__always) func helper28(_ x: Int) -> Int { x &* 3 &+ 28 }
@inline(__always) func helper29(_ x: Int) -> Int { x &* 3 &+ 29 }
@inline(__always) func helper30(_ x: Int) -> Int { x &* 3 &+ 30 }
@inline(__always) func helper31(_ x: Int) -> Int { x &* 3 &+ 31 }

public func entry(_ x: Int) -> Int {
  return helper31(helper30(helper29(helper28(helper27(helper26(helper25(
    helper24(helper23(helper22(helper21(helper20(helper19(helper18(helper17(
    helper16(helper15(helper14(helper13(helper12(helper11(helper10(helper9(
    helper8(helper7(helper6(helper5(helper4(helper3(helper2(helper1(helper0(x
    ))))))))))))))))))))))))))))))))
}
