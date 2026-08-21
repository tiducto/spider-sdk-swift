public struct TransferPreferencesInput: Codable, Sendable {
    public let cost: Int?
    public let maximumAdditionalTransfers: Int?
    public let maximumTransfers: Int?
    public let slack: String?

    public init(
        cost: Int? = nil,
        maximumAdditionalTransfers: Int? = nil,
        maximumTransfers: Int? = nil,
        slack: String? = nil
    ) {
        self.cost = cost
        self.maximumAdditionalTransfers = maximumAdditionalTransfers
        self.maximumTransfers = maximumTransfers
        self.slack = slack
    }
}
