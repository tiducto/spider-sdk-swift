public struct TransitModePreferenceCostInput: Codable, Sendable {
    public let reluctance: Double

    public init(
        reluctance: Double
    ) {
        self.reluctance = reluctance
    }
}
