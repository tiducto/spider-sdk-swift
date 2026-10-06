/// Sent once, after the last `chunk`. To continue, send `endCursor` as `after` or `startCursor` as `before` in a new request.
public struct PlanStreamPageInfoEvent: Codable, Sendable {
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool
    /// Why the plan was declined; empty when it was not.
    public let routingErrors: [RoutingError]
    /// Send as `before` for earlier itineraries; null when there is none.
    public let startCursor: String?
    /// Send as `after` for later itineraries; null when there is none.
    public let endCursor: String?
    /// The window the stream searched, as an ISO-8601 duration; null for a declined plan.
    public let searchWindowUsed: String?

    public init(
        hasNextPage: Bool,
        hasPreviousPage: Bool,
        routingErrors: [RoutingError],
        startCursor: String? = nil,
        endCursor: String? = nil,
        searchWindowUsed: String? = nil
    ) {
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
        self.routingErrors = routingErrors
        self.startCursor = startCursor
        self.endCursor = endCursor
        self.searchWindowUsed = searchWindowUsed
    }
}
