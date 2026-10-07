public struct PlanPageInfo: Codable, Sendable {
    /// True exactly when `endCursor` is present.
    public let hasNextPage: Bool
    /// True exactly when `startCursor` is present.
    public let hasPreviousPage: Bool
    /// Send as `before` for the previous page; null when there is none, as for a declined, direct-only or unroutable plan.
    public let startCursor: String?
    /// Send as `after` for the next page; null when there is none, as for a declined, direct-only or unroutable plan.
    public let endCursor: String?
    /// The window the search covered, as an ISO-8601 duration; null when no transit search ran, as for a declined, direct-only or unroutable plan.
    public let searchWindowUsed: String?

    public init(
        hasNextPage: Bool,
        hasPreviousPage: Bool,
        startCursor: String? = nil,
        endCursor: String? = nil,
        searchWindowUsed: String? = nil
    ) {
        self.hasNextPage = hasNextPage
        self.hasPreviousPage = hasPreviousPage
        self.startCursor = startCursor
        self.endCursor = endCursor
        self.searchWindowUsed = searchWindowUsed
    }
}
