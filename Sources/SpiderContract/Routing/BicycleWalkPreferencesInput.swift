public struct BicycleWalkPreferencesInput: Codable, Sendable {
    public let cost: BicycleWalkPreferencesCostInput?
    public let mountDismountTime: String?
    public let speed: Double?

    public init(
        cost: BicycleWalkPreferencesCostInput? = nil,
        mountDismountTime: String? = nil,
        speed: Double? = nil
    ) {
        self.cost = cost
        self.mountDismountTime = mountDismountTime
        self.speed = speed
    }
}
