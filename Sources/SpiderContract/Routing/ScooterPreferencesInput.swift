public struct ScooterPreferencesInput: Codable, Sendable {
    public let optimization: ScooterOptimizationInput?
    public let reluctance: Double?
    public let rental: ScooterRentalPreferencesInput?
    public let speed: Double?

    public init(
        optimization: ScooterOptimizationInput? = nil,
        reluctance: Double? = nil,
        rental: ScooterRentalPreferencesInput? = nil,
        speed: Double? = nil
    ) {
        self.optimization = optimization
        self.reluctance = reluctance
        self.rental = rental
        self.speed = speed
    }
}
