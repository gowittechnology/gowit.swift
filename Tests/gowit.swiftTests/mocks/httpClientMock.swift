import Foundation
@testable import Gowit

class MockHTTPClient: HTTPClientProtocol {
    var postResult: Result<Data?, NetworkFailure> = .success(nil)
    var getResult: Result<Data?, NetworkFailure> = .success(nil)
    var postCalled = false
    /// Delay before `asyncPost` returns, to simulate a slow server.
    var postDelay: TimeInterval = 0
    /// Timeout passed to the last `asyncPost` call.
    var lastPostTimeout: TimeInterval?
    var getCalled = false

    init(
        postResult: Result<Data?, NetworkFailure> = .success(nil),
        getResult: Result<Data?, NetworkFailure> = .success(nil)
    ) {
        self.postResult = postResult
        self.getResult = getResult
    }

    func post(url: URL, data: Data, callback: @escaping (Result<Data?, NetworkFailure>) -> Void) {
        postCalled = true
        callback(postResult)
    }

    func asyncPost(url: URL, data: Data, timeoutInterval: TimeInterval = 60) async throws(NetworkFailure) -> Data? {
        postCalled = true
        lastPostTimeout = timeoutInterval
        if postDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(postDelay * 1_000_000_000))
            if Task.isCancelled {
                throw NetworkFailure.connectivity(
                    underlying: CancellationError(),
                    context: NetworkContext(endpoint: url.absoluteString, method: .POST)
                )
            }
        }
        switch postResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }

    func get(url: URL, callback: @escaping (Result<Data?, NetworkFailure>) -> Void) {
        getCalled = true
        callback(getResult)
    }

    func asyncGet(url: URL, timeoutInterval: TimeInterval = 60) async throws(NetworkFailure) -> Data? {
        getCalled = true
        switch getResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
