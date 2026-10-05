import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated enum GitHubDeviceOAuthHTTP {
    static let maximumResponseBytes = 64 * 1024
    private static let sharedSession = session(configuration: configuration())

    static func session(configuration: URLSessionConfiguration) -> URLSession {
        URLSession(configuration: configuration, delegate: GitHubDeviceOAuthDelegate(), delegateQueue: nil)
    }

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    static func send(_ endpoint: String, fields: [String: String], session: URLSession?) async throws -> Data {
        guard ["device/code", "oauth/access_token"].contains(endpoint),
              let url = URL(string: "https://github.com/login/\(endpoint)")
        else { throw GitHubDeviceOAuthError.unsafeResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("LeadStone", forHTTPHeaderField: "User-Agent")
        request
            .httpBody = Data(fields.keys.sorted().map { "\(encode($0))=\(encode(fields[$0] ?? ""))" }
                .joined(separator: "&").utf8)
        // A per-request delegate enforces the same streaming bound on Apple and corelibs Foundation.
        let receiver = GitHubDeviceOAuthReceiver(url: url)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let data = try await receiver.receive(request, session: session ?? sharedSession)
            try Task.checkCancellation()
            return data
        } onCancel: {
            receiver.finish(.failure(CancellationError()))
        }
    }

    private static func encode(_ value: String) -> String {
        value
            .addingPercentEncoding(
                withAllowedCharacters: CharacterSet(
                    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
                )
            ) ??
            ""
    }
}

/// Route delegate-based data tasks consistently on Apple and corelibs Foundation.
private final nonisolated class GitHubDeviceOAuthDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let receiver = task.delegate as? GitHubDeviceOAuthReceiver else {
            completionHandler(nil)
            return
        }
        receiver.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: request,
            completionHandler: completionHandler
        )
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let receiver = dataTask.delegate as? GitHubDeviceOAuthReceiver else {
            completionHandler(.cancel)
            return
        }
        receiver.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        (dataTask.delegate as? GitHubDeviceOAuthReceiver)?.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        (task.delegate as? GitHubDeviceOAuthReceiver)?.urlSession(session, task: task, didCompleteWithError: error)
    }
}

private final nonisolated class GitHubDeviceOAuthReceiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var task: URLSessionDataTask?
    private var result: Result<Data, Error>?
    private var body = Data()

    init(url: URL) {
        self.url = url
    }

    func receive(_ request: URLRequest, session: URLSession) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
                return
            }
            self.continuation = continuation
            let task = session.dataTask(with: request)
            task.delegate = self
            self.task = task
            task.resume()
            lock.unlock()
        }
    }

    func finish(_ result: Result<Data, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        let task = task
        self.task = nil
        body.removeAll(keepingCapacity: false)
        lock.unlock()
        task?.cancel()
        continuation?.resume(with: result)
    }

    func urlSession(
        _: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
        finish(.failure(GitHubDeviceOAuthError.unsafeResponse))
    }

    func urlSession(
        _: URLSession, dataTask _: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse, response.url == url,
              !(300 ... 399).contains(response.statusCode)
        else {
            completionHandler(.cancel)
            finish(.failure(GitHubDeviceOAuthError.unsafeResponse))
            return
        }
        guard response.statusCode == 200 else {
            completionHandler(.cancel)
            finish(.failure(GitHubDeviceOAuthError.authorizationFailed))
            return
        }
        guard response.expectedContentLength <= GitHubDeviceOAuthHTTP.maximumResponseBytes else {
            completionHandler(.cancel)
            finish(.failure(GitHubDeviceOAuthError.responseTooLarge))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        guard data.count <= GitHubDeviceOAuthHTTP.maximumResponseBytes - body.count else {
            lock.unlock()
            finish(.failure(GitHubDeviceOAuthError.responseTooLarge))
            return
        }
        body.append(data)
        lock.unlock()
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let code = (error as? URLError)?.code ?? .unknown
            let failure: Error = code == .cancelled
                ? CancellationError() : GitHubDeviceOAuthError.connectionFailed(code)
            finish(.failure(failure))
        } else {
            let data = lock.withLock { body }
            finish(.success(data))
        }
    }
}
