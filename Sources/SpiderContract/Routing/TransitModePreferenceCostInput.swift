/// Cost settings for a transit mode.
public struct TransitModePreferenceCostInput: Codable, Sendable {
    /// Multiplier on the time spent riding this mode, from 0.1 to 100000: above 1 avoids the mode, below 1 favours it; rejected, never clamped.
    public let reluctance: Double

    public init(
        reluctance: Double
    ) {
        self.reluctance = reluctance
    }
}
