public struct BicycleParkingPreferencesInput: Codable, Sendable {
    public let filters: [ParkingFilter]?
    public let preferred: [ParkingFilter]?
    public let unpreferredCost: Int?

    public init(
        filters: [ParkingFilter]? = nil,
        preferred: [ParkingFilter]? = nil,
        unpreferredCost: Int? = nil
    ) {
        self.filters = filters
        self.preferred = preferred
        self.unpreferredCost = unpreferredCost
    }
}
