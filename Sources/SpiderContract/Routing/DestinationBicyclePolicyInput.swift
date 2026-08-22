public struct DestinationBicyclePolicyInput: Codable, Sendable {
    public let allowKeeping: Bool?
    public let keepingCost: Int?

    public init(
        allowKeeping: Bool? = nil,
        keepingCost: Int? = nil
    ) {
        self.allowKeeping = allowKeeping
        self.keepingCost = keepingCost
    }
}
