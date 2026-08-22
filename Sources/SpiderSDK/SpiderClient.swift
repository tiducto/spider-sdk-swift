import Foundation

/// Per-surface retry configuration. Retries are opt-in: leave `autoRetry` nil to disable (the default).
public struct AutoRetryOptions: Sendable {
    /// Total attempts including the first (default 3 when auto-retry is enabled).
    public var maxAttempts: Int?
    public init(maxAttempts: Int? = nil) { self.maxAttempts = maxAttempts }
}

/// Feature toggles for one surface (routing / stops / realtime).
public struct FeatureOptions: Sendable {
    public var autoRetry: AutoRetryOptions?
    public init(autoRetry: AutoRetryOptions? = nil) { self.autoRetry = autoRetry }
}

/// Client-wide options: a shared HTTP client + timeout, and per-surface feature toggles.
public struct SpiderClientOptions {
    /// Inject a custom HTTP client (tests, proxies). Defaults to `URLSessionHTTPClient(session: .shared)`.
    public var httpClient: HTTPClient?
    /// Per-request timeout in seconds (default 30).
    public var timeout: TimeInterval?
    public var routing: FeatureOptions?
    public var stops: FeatureOptions?
    public var realtime: FeatureOptions?

    public init(
        httpClient: HTTPClient? = nil,
        timeout: TimeInterval? = nil,
        routing: FeatureOptions? = nil,
        stops: FeatureOptions? = nil,
        realtime: FeatureOptions? = nil
    ) {
        self.httpClient = httpClient
        self.timeout = timeout
        self.routing = routing
        self.stops = stops
        self.realtime = realtime
    }
}

/// The Spider API client. Construct once with your environment base URL and API key, then reach a surface:
/// `client.routing`, `client.stops`, `client.realtime`. Each surface gets its own transport (own retry config)
/// sharing the same base URL, key, HTTP client and timeout.
public final class SpiderClient {
    public let routing: SpiderRouting
    public let stops: SpiderStops
    public let realtime: SpiderRealtime

    public init(baseURL: String, apiKey: String, options: SpiderClientOptions = SpiderClientOptions()) {
        let httpClient = options.httpClient ?? URLSessionHTTPClient()
        let timeout = options.timeout ?? 30

        func transport(_ feature: FeatureOptions?) -> Transport {
            let retry = feature?.autoRetry.map { RetryConfig(maxAttempts: $0.maxAttempts ?? 3) }
            return Transport(
                baseURL: baseURL,
                apiKey: apiKey,
                config: TransportConfig(httpClient: httpClient, timeout: timeout, retry: retry)
            )
        }

        self.routing = SpiderRouting(transport: transport(options.routing))
        self.stops = SpiderStops(transport: transport(options.stops))
        self.realtime = SpiderRealtime(transport: transport(options.realtime))
    }

    /// The contract (major.minor) version this SDK speaks.
    public var contractVersion: String { CONTRACT_VERSION }
}
