import Foundation
import os.log
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Network Request Context
public struct NetworkContext {
    let requestId: UUID
    let startTime: Date
    let endpoint: String
    let method: HTTPMethod

    init(endpoint: String, method: HTTPMethod) {
        self.requestId = UUID()
        self.startTime = Date()
        self.endpoint = endpoint
        self.method = method
    }
}

public enum HTTPMethod: String, CaseIterable {
    case GET
    case POST
}

// MARK: - Network Failure Types
public enum NetworkFailure: LocalizedError {
    case connectivity(underlying: Error, context: NetworkContext)
    case serverResponse(statusCode: Int, payload: ResponsePayload?, context: NetworkContext)
    case timeout(context: NetworkContext)
    case invalidConfiguration(reason: String)
    case dataCorruption(context: NetworkContext)

    public var errorDescription: String? {
        switch self {
        case .connectivity(let error, _):
            return "Network connectivity failed: \(error.localizedDescription)"
        case .serverResponse(let code, _, _):
            return "Server responded with status: \(code)"
        case .timeout:
            return "Request timed out"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .dataCorruption:
            return "Response data was corrupted"
        }
    }

    public var failureReason: String? {
        switch self {
        case .connectivity(let error, let context):
            return "Request \(context.requestId) failed: \(error.localizedDescription)"
        case .serverResponse(let code, _, let context):
            return "Request \(context.requestId) received HTTP \(code)"
        case .timeout(let context):
            return "Request \(context.requestId) exceeded timeout limit"
        case .invalidConfiguration(let reason):
            return "Configuration issue: \(reason)"
        case .dataCorruption(let context):
            return "Request \(context.requestId) received corrupted data"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectivity:
            return "Verify network connection and retry"
        case .serverResponse(let code, _, _):
            return HTTPStatusCodeHandler.recoverySuggestion(for: code)
        case .timeout:
            return "Increase timeout duration or retry with better connection"
        case .invalidConfiguration:
            return "Check SDK configuration parameters"
        case .dataCorruption:
            return "Retry the request or contact support"
        }
    }
}

extension NetworkFailure {
    func isRetriable() -> Bool {
        switch self {
        case .connectivity, .timeout:
            return true
        case .serverResponse(let code, _, _):
            return code >= 500
        case .invalidConfiguration, .dataCorruption:
            return false
        }
    }
}

// MARK: - Response Payload
public enum ResponsePayload {
    case raw(Data)
    case structured(GowitError)
    case empty
}
extension ResponsePayload {
    static func from(_ data: Data?) -> ResponsePayload {
        guard let data = data, !data.isEmpty else { return .empty }

        if let structuredError = try? JSONDecoder().decode(GowitError.self, from: data) {
            return .structured(structuredError)
        }
        return .raw(data)
    }
}

// MARK: - Retry Strategy
public struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0
    )

    func shouldRetry(_ failure: NetworkFailure, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        switch failure {
        case .connectivity, .timeout:
            return true
        case .serverResponse(let code, _, _):
            return code >= 500 // Only retry server errors
        case .invalidConfiguration, .dataCorruption:
            return false
        }
    }

    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - HTTP Status Code Handler
struct HTTPStatusCodeHandler {
    static func recoverySuggestion(for statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Verify request parameters and format"
        case 401:
            return "Check API key authentication"
        case 403:
            return "Verify access permissions for this resource"
        case 404:
            return "Confirm the endpoint URL is correct"
        case 429:
            return "Reduce request frequency and retry later"
        case 500...599:
            return "Server issue - retry later or contact support"
        default:
            return "Review request and try again"
        }
    }
}

// MARK: - Network Service Protocol
public protocol NetworkServiceProtocol {
    var credentials: NetworkCredentials? { get set }

    func execute<T: Codable>(
        _ request: NetworkRequest<T>,
        timeout: TimeInterval
    ) async throws -> NetworkResponse<T>
}

// MARK: - Network Credentials

public struct NetworkCredentials {
    let userAgent: String
    init(sdkVersion: String = gowitVersion) {
        self.userAgent = "gowit-swift/\(sdkVersion)"
    }
}

// MARK: - Network Request
public struct NetworkRequest<T: Codable> {
    let endpoint: URL
    let method: HTTPMethod
    let payload: Data?
    let expectedType: T.Type

    init(endpoint: URL, method: HTTPMethod, payload: Data? = nil, expecting: T.Type) {
        self.endpoint = endpoint
        self.method = method
        self.payload = payload
        self.expectedType = expecting
    }
}

// MARK: - Network Response
public struct NetworkResponse<T: Codable> {
    let data: T?
    let context: NetworkContext
    let duration: TimeInterval

    init(data: T?, context: NetworkContext) {
        self.data = data
        self.context = context
        self.duration = Date().timeIntervalSince(context.startTime)
    }
}

// MARK: - Advanced Network Service Implementation

class AdvancedNetworkService: NetworkServiceProtocol {
    public var credentials: NetworkCredentials?
    private let sessionManager: URLSessionManager
    private let retryPolicy: RetryConfiguration
    private let logger: NetworkLogger
    init(
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        retryPolicy: RetryConfiguration = .default,
        enableLogging: Bool = false
    ) {
        self.sessionManager = URLSessionManager(configuration: sessionConfiguration)
        self.retryPolicy = retryPolicy
        self.logger = NetworkLogger(enabled: enableLogging)
    }
    public func execute<T: Codable>(
        _ request: NetworkRequest<T>,
        timeout: TimeInterval = 60.0
    ) async throws -> NetworkResponse<T> {
        let context = NetworkContext(endpoint: request.endpoint.absoluteString, method: request.method)
        logger.logRequestStart(context)
        var lastFailure: NetworkFailure?
        for attempt in 1...retryPolicy.maxAttempts {
            do {
                let response = try await performSingleRequest(request, timeout: timeout, context: context)
                logger.logRequestSuccess(context, attempt: attempt)
                return response
            } catch let failure as NetworkFailure {
                lastFailure = failure
                logger.logRequestFailure(context, failure: failure, attempt: attempt)

                if retryPolicy.shouldRetry(failure, attempt: attempt) {
                    let delay = retryPolicy.delay(for: attempt)
                    logger.logRetryAttempt(context, attempt: attempt, delay: delay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }

        throw lastFailure ?? NetworkFailure.invalidConfiguration(reason: "Unknown error occurred")
    }

    private func performSingleRequest<T: Codable>(
        _ request: NetworkRequest<T>,
        timeout: TimeInterval,
        context: NetworkContext
    ) async throws -> NetworkResponse<T> {
        let urlRequest = try buildURLRequest(from: request, timeout: timeout)

        let (responseData, urlResponse): (Data, URLResponse)
        do {
            (responseData, urlResponse) = try await sessionManager.performRequest(urlRequest)
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkFailure.timeout(context: context)
            }
            throw NetworkFailure.connectivity(underlying: error, context: context)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkFailure.dataCorruption(context: context)
        }
        return try processResponse(
            data: responseData,
            httpResponse: httpResponse,
            expectedType: request.expectedType,
            context: context
        )
    }

    private func buildURLRequest<T: Codable>(from request: NetworkRequest<T>, timeout: TimeInterval) throws -> URLRequest {
        guard let credentials = credentials else {
            throw NetworkFailure.invalidConfiguration(reason: "Network credentials not configured")
        }

        var urlRequest = URLRequest(
            url: request.endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )

        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(credentials.userAgent, forHTTPHeaderField: "User-Agent")
        // No authorization header needed for SDK endpoint

        if let payload = request.payload {
            urlRequest.httpBody = payload
        }

        return urlRequest
    }

    private func processResponse<T: Codable>(
        data: Data,
        httpResponse: HTTPURLResponse,
        expectedType: T.Type,
        context: NetworkContext
    ) throws -> NetworkResponse<T> {
        // Handle 204 No Content as success with nil data
        if httpResponse.statusCode == 204 {
            return NetworkResponse(data: nil, context: context)
        }

        // Handle error status codes
        if httpResponse.statusCode >= 400 {
            let payload = ResponsePayload.from(data)
            throw NetworkFailure.serverResponse(
                statusCode: httpResponse.statusCode,
                payload: payload,
                context: context
            )
        }

        // For successful responses, decode if data is present
        if !data.isEmpty {
            do {
                let decodedData = try JSONDecoder().decode(expectedType, from: data)
                return NetworkResponse(data: decodedData, context: context)
            } catch {
                throw NetworkFailure.dataCorruption(context: context)
            }
        }

        return NetworkResponse(data: nil, context: context)
    }
}

// MARK: - URL Session Manager

class URLSessionManager {
    private let session: URLSession

    init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }

    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}

// MARK: - Network Logger

class NetworkLogger {
    private let enabled: Bool
    private let logger = Logger(subsystem: "com.gowit.sdk", category: "NetworkService")

    init(enabled: Bool) {
        self.enabled = enabled
    }

    func logRequestStart(_ context: NetworkContext) {
        guard enabled else { return }
        logger.info("[\(context.requestId.uuidString.prefix(8))] Starting \(context.method.rawValue) \(context.endpoint)")
    }

    func logRequestSuccess(_ context: NetworkContext, attempt: Int) {
        guard enabled else { return }
        let duration = Date().timeIntervalSince(context.startTime)
        logger.info("[\(context.requestId.uuidString.prefix(8))] Success after \(attempt) attempt(s) in \(String(format: "%.3f", duration))s")
    }

    func logRequestFailure(_ context: NetworkContext, failure: NetworkFailure, attempt: Int) {
        guard enabled else { return }
        logger.error("[\(context.requestId.uuidString.prefix(8))] Attempt \(attempt) failed: \(failure.localizedDescription)")
    }

    func logRetryAttempt(_ context: NetworkContext, attempt: Int, delay: TimeInterval) {
        guard enabled else { return }
        logger.info("[\(context.requestId.uuidString.prefix(8))] Retrying in \(String(format: "%.1f", delay))s (attempt \(attempt + 1))")
    }
}

// MARK: - Legacy Compatibility Layer

public typealias HTTPClientError = NetworkFailure
public typealias ErrorData = ResponsePayload

public protocol HTTPClientProtocol {
    func asyncPost(url: URL, data: Data, timeoutInterval: TimeInterval) async throws(HTTPClientError) -> Data?
    func post(url: URL, data: Data, callback: @escaping (Result<Data?, HTTPClientError>) -> Void)
    func asyncGet(url: URL, timeoutInterval: TimeInterval) async throws(HTTPClientError) -> Data?
    func get(url: URL, callback: @escaping (Result<Data?, HTTPClientError>) -> Void)
}

// MARK: - Legacy HTTP Client Adapter

class HTTPClient: HTTPClientProtocol {
    private var networkService: NetworkServiceProtocol

    init() {
        self.networkService = AdvancedNetworkService()
        // Set default credentials without API key
        self.networkService.credentials = NetworkCredentials()
    }

    public func asyncPost(url: URL, data: Data, timeoutInterval: TimeInterval = 60)
    async throws(HTTPClientError) -> Data? {
        return try await performLegacyRequest(url: url, data: data, timeout: timeoutInterval)
    }

    private func performLegacyRequest(url: URL, data: Data, timeout: TimeInterval)
    async throws(NetworkFailure) -> Data? {
        guard let credentials = networkService.credentials else {
            throw NetworkFailure.invalidConfiguration(reason: "Network service not configured")
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.userAgent, forHTTPHeaderField: "User-Agent")
        // No authorization header needed for SDK endpoint
        request.httpBody = data

        let context = NetworkContext(endpoint: url.absoluteString, method: .POST)

        do {
            let (responseData, urlResponse) = try await URLSession.shared.data(for: request)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkFailure.dataCorruption(context: context)
            }

            if httpResponse.statusCode == 204 {
                return nil
            }

            if httpResponse.statusCode >= 400 {
                let payload = ResponsePayload.from(responseData)
                throw NetworkFailure.serverResponse(
                    statusCode: httpResponse.statusCode,
                    payload: payload,
                    context: context
                )
            }

            return responseData
        } catch let error as NetworkFailure {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkFailure.timeout(context: context)
            }
            throw NetworkFailure.connectivity(underlying: error, context: context)
        }
    }

    public func post(url: URL, data: Data, callback: @escaping (Result<Data?, HTTPClientError>) -> Void) {
        Task {
            do {
                let result = try await asyncPost(url: url, data: data, timeoutInterval: 60)
                callback(.success(result))
            } catch let error as HTTPClientError {
                callback(.failure(error))
            }
        }
    }

    public func asyncGet(url: URL, timeoutInterval: TimeInterval = 60) async throws(HTTPClientError) -> Data? {
        return try await performLegacyGetRequest(url: url, timeout: timeoutInterval)
    }

    private func performLegacyGetRequest(url: URL, timeout: TimeInterval) async throws(NetworkFailure) -> Data? {
        guard let credentials = networkService.credentials else {
            throw NetworkFailure.invalidConfiguration(reason: "Network service not configured")
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(credentials.userAgent, forHTTPHeaderField: "User-Agent")
        // No authorization header needed for SDK endpoint

        let context = NetworkContext(endpoint: url.absoluteString, method: .GET)

        do {
            let (responseData, urlResponse) = try await URLSession.shared.data(for: request)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkFailure.dataCorruption(context: context)
            }

            if httpResponse.statusCode == 204 {
                return nil
            }

            if httpResponse.statusCode >= 400 {
                let payload = ResponsePayload.from(responseData)
                throw NetworkFailure.serverResponse(
                    statusCode: httpResponse.statusCode,
                    payload: payload,
                    context: context
                )
            }

            return responseData
        } catch let error as NetworkFailure {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkFailure.timeout(context: context)
            }
            throw NetworkFailure.connectivity(underlying: error, context: context)
        }
    }

    public func get(url: URL, callback: @escaping (Result<Data?, HTTPClientError>) -> Void) {
        Task {
            do {
                let result = try await asyncGet(url: url, timeoutInterval: 60)
                callback(.success(result))
            } catch let error as HTTPClientError {
                callback(.failure(error))
            }
        }
    }
}
