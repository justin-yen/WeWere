import Foundation

enum AppNetwork {
    static let session: URLSession = {
        #if DEBUG && STAGING && targetEnvironment(simulator)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StagingFaultProtocol.self]
        return URLSession(configuration: config)
        #else
        return .shared
        #endif
    }()
}

#if DEBUG && STAGING && targetEnvironment(simulator)
/// Faults affect only this simulator app's API/auth HTTP transport.
/// Healthy responses are fetched from real staging services, never fabricated.
final class StagingFaultProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var refreshes = 0
    private var forwardedTask: URLSessionDataTask?
    private let deliveryLock = NSRecursiveLock()
    private var stopped = false

    static var mode: String {
        get { UserDefaults.standard.string(forKey: "validation.networkMode") ?? "live" }
        set { UserDefaults.standard.set(newValue, forKey: "validation.networkMode") }
    }
    static var refreshCount: Int {
        lock.lock(); defer { lock.unlock() }; return refreshes
    }
    static func resetCounts() { lock.lock(); refreshes = 0; lock.unlock() }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host == URL(string: AppEnvironment.apiURL)?.host || host == URL(string: AppEnvironment.supabaseURL)?.host
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let mode = Self.mode
        let isRefresh = request.url?.path == "/auth/v1/token"
        if isRefresh { Self.lock.lock(); Self.refreshes += 1; Self.lock.unlock() }
        if mode == "offline" { finish(nil, nil, URLError(.notConnectedToInternet)); return }
        if mode == "503" {
            finish(Data("{\"detail\":\"Injected staging outage\"}".utf8), response(503), nil); return
        }
        if mode == "revoked" && isRefresh {
            finish(Data("{\"code\":400,\"error_code\":\"refresh_token_not_found\"}".utf8), response(400), nil); return
        }
        var forwarded = request
        // URLProtocol receives upload bodies as streams on some OS versions.
        if forwarded.httpBody == nil, let stream = forwarded.httpBodyStream {
            stream.open(); defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let length = stream.read(&buffer, maxLength: buffer.count)
                if length < 0 { finish(nil, nil, stream.streamError ?? URLError(.cannotDecodeRawData)); return }
                if length == 0 { break }
                body.append(buffer, count: length)
            }
            forwarded.httpBodyStream = nil
            forwarded.httpBody = body
        }
        forwardedTask = URLSession.shared.dataTask(with: forwarded) { [weak self] data, response, error in
            guard let self else { return }
            if mode == "delayed" && isRefresh {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self.finish(data, response, error)
                }
            } else { self.finish(data, response, error) }
        }
        forwardedTask?.resume()
    }
    private func response(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    }
    private func finish(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        deliveryLock.lock(); defer { deliveryLock.unlock() }
        guard !stopped else { return }
        if let error { client?.urlProtocol(self, didFailWithError: error); return }
        if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
        if let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {
        deliveryLock.lock(); stopped = true; deliveryLock.unlock()
        forwardedTask?.cancel()
    }
}
#endif
