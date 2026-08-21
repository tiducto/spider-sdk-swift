public struct BicycleRentalPreferencesInput: Codable, Sendable {
    public let allowedNetworks: [String]?
    public let bannedNetworks: [String]?
    public let destinationBicyclePolicy: DestinationBicyclePolicyInput?

    public init(
        allowedNetworks: [String]? = nil,
        bannedNetworks: [String]? = nil,
        destinationBicyclePolicy: DestinationBicyclePolicyInput? = nil
    ) {
        self.allowedNetworks = allowedNetworks
        self.bannedNetworks = bannedNetworks
        self.destinationBicyclePolicy = destinationBicyclePolicy
    }
}
