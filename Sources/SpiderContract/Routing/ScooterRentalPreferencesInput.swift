public struct ScooterRentalPreferencesInput: Codable, Sendable {
    public let allowedNetworks: [String]?
    public let bannedNetworks: [String]?
    public let destinationScooterPolicy: DestinationScooterPolicyInput?

    public init(
        allowedNetworks: [String]? = nil,
        bannedNetworks: [String]? = nil,
        destinationScooterPolicy: DestinationScooterPolicyInput? = nil
    ) {
        self.allowedNetworks = allowedNetworks
        self.bannedNetworks = bannedNetworks
        self.destinationScooterPolicy = destinationScooterPolicy
    }
}
