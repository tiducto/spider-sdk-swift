public struct PlanPageInfo: Codable, Sendable {
    /// Send as `before` for the previous page; null when there is none, as for a declined, direct-only or unroutable plan.
    public let startCursor: String
    /// Send as `after` for the next page; null when there is none, as for a declined, direct-only or unroutable plan.
    public let endCursor: String
    /// True exactly when `endCursor` is present.
    public let hasNextPage: Bool
    /// True exactly when `startCursor` is present.
    public let hasPreviousPage: Bool
    /// The window the search covered, as an ISO-8601 duration; null when no transit search ran, as for a declined, direct-only or unroutable plan.
    public let searchWindowUsed: String

    public init(
        startCursor: String,
        endCursor: String,
        hasNextPage: Bool,
        hasPreviousPage: Bool,
        searchWindowUsed: String
    ) {
        self.startCursor = startCursor
        self.endCursor = endCursor
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
        self.searchWindowUsed = searchWindowUsed
    }
}
