/// Sent once, after the last `chunk`. To continue, send `endCursor` as `after` or `startCursor` as `before` in a new request.
public struct PlanStreamPageInfoEvent: Codable, Sendable {
    /// Send as `before` for earlier itineraries; null when there is none, as for a declined, direct-only or unroutable plan.
    public let startCursor: String
    /// Send as `after` for later itineraries; null when there is none, as for a declined, direct-only or unroutable plan.
    public let endCursor: String
    /// True exactly when `endCursor` is present.
    public let hasNextPage: Bool
    /// True exactly when `startCursor` is present.
    public let hasPreviousPage: Bool
    /// The window the stream searched, as an ISO-8601 duration; null when no transit search ran, as for a declined, direct-only or unroutable plan.
    public let searchWindowUsed: String
    /// Why the plan was declined; empty when it was not.
    public let routingErrors: [RoutingError]

    public init(
        startCursor: String,
        endCursor: String,
        hasNextPage: Bool,
        hasPreviousPage: Bool,
        searchWindowUsed: String,
        routingErrors: [RoutingError]
    ) {
        self.startCursor = startCursor
        self.endCursor = endCursor
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
        self.searchWindowUsed = searchWindowUsed
        self.routingErrors = routingErrors
    }
}
