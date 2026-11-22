// A closure with an explicit typed `throws(RequestError)` is passed to a
// generic parameter declared with untyped `throws`.
struct RequestError: Error {
  let code: Int
  let message: String
}

func work() async throws(RequestError) -> Int { fatalError() }

func generic<T>(_ op: () async throws -> T) {}

func caller() {
  generic { () async throws(RequestError) -> Int in try await work() }
}

func callerWithTask() async throws -> Int {
  let task = Task { () async throws(RequestError) -> Int in try await work() }
  return try await task.value
}
