public struct BicyclePreferencesInput: Codable, Sendable {
    public let boardCost: Int?
    public let optimization: CyclingOptimizationInput?
    public let parking: BicycleParkingPreferencesInput?
    public let reluctance: Double?
    public let rental: BicycleRentalPreferencesInput?
    public let speed: Double?
    public let walk: BicycleWalkPreferencesInput?

    public init(
        boardCost: Int? = nil,
        optimization: CyclingOptimizationInput? = nil,
        parking: BicycleParkingPreferencesInput? = nil,
        reluctance: Double? = nil,
        rental: BicycleRentalPreferencesInput? = nil,
        speed: Double? = nil,
        walk: BicycleWalkPreferencesInput? = nil
    ) {
        self.boardCost = boardCost
        self.optimization = optimization
        self.parking = parking
        self.reluctance = reluctance
        self.rental = rental
        self.speed = speed
        self.walk = walk
    }
}
