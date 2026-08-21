public struct CarRentalPreferencesInput: Codable, Sendable {
    public let allowedNetworks: [String]?
    public let bannedNetworks: [String]?
    public let rentalDuration: String?

    public init(
        allowedNetworks: [String]? = nil,
        bannedNetworks: [String]? = nil,
        rentalDuration: String? = nil
    ) {
        self.allowedNetworks = allowedNetworks
        self.bannedNetworks = bannedNetworks
        self.rentalDuration = rentalDuration
    }
}
