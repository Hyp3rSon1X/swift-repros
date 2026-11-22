// #isolation inside a nonisolated(nonsending) function is passed to a
// consuming generic argument without a copy, which releases the calling actor once too often.
actor Worker {
  deinit { print("Worker.deinit") }
  func run() async -> String { await describeIsolation() }
}

nonisolated(nonsending) func describeIsolation() async -> String {
  String(describing: #isolation)
}

func test() async {
  let worker = Worker()
  print("1:", await worker.run())
  print("2:", await worker.run())
  print("end of test()")
}

await test()
print("done")
