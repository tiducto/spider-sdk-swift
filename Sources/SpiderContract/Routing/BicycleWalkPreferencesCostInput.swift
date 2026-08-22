public struct BicycleWalkPreferencesCostInput: Codable, Sendable {
    public let mountDismountCost: Int?
    public let reluctance: Double?

    public init(
        mountDismountCost: Int? = nil,
        reluctance: Double? = nil
    ) {
        self.mountDismountCost = mountDismountCost
        self.reluctance = reluctance
    }
}
