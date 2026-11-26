/// The reluctance of one transit mode, a Spider extension.
public struct TransitModeCostInput: Codable, Sendable {
    public let mode: TransitMode
    /// Multiplier on the time spent riding this mode, from 0.1 to 100000: above 1 avoids the mode, below 1 favours it; rejected, never clamped.
    public let reluctance: Double

    public init(
        mode: TransitMode,
        reluctance: Double
    ) {
        self.mode = mode
        self.reluctance = reluctance
    }
}
