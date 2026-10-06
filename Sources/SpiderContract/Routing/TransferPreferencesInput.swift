/// Transfer preferences.
public struct TransferPreferencesInput: Codable, Sendable {
    /// Generalized cost added for each transfer, an integer from 0 to 1000000; rejected, never clamped.
    public let cost: Int?
    /// Least time between alighting one vehicle and boarding the next, on top of the walk between stops, as an ISO-8601 duration: `PT0S` to `PT1H`; rejected, never clamped.
    public let slack: String?
    /// Most rides an itinerary may take: `N` allows `N - 1` transfers, and `0` allows walking only. From 0 up to the environment's transfer limit plus 1; rejected, never clamped. Absent means the environment's limit.
    public let maximumTransfers: Int?

    public init(
        cost: Int? = nil,
        slack: String? = nil,
        maximumTransfers: Int? = nil
    ) {
        self.cost = cost
        self.slack = slack
        self.maximumTransfers = maximumTransfers
    }
}
