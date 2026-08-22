public struct PlanStreetPreferencesInput: Codable, Sendable {
    public let bicycle: BicyclePreferencesInput?
    public let car: CarPreferencesInput?
    public let scooter: ScooterPreferencesInput?
    public let walk: WalkPreferencesInput?

    public init(
        bicycle: BicyclePreferencesInput? = nil,
        car: CarPreferencesInput? = nil,
        scooter: ScooterPreferencesInput? = nil,
        walk: WalkPreferencesInput? = nil
    ) {
        self.bicycle = bicycle
        self.car = car
        self.scooter = scooter
        self.walk = walk
    }
}
