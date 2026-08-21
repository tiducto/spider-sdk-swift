public struct CarPreferencesInput: Codable, Sendable {
    public let boardCost: Int?
    public let parking: CarParkingPreferencesInput?
    public let reluctance: Double?
    public let rental: CarRentalPreferencesInput?

    public init(
        boardCost: Int? = nil,
        parking: CarParkingPreferencesInput? = nil,
        reluctance: Double? = nil,
        rental: CarRentalPreferencesInput? = nil
    ) {
        self.boardCost = boardCost
        self.parking = parking
        self.reluctance = reluctance
        self.rental = rental
    }
}
