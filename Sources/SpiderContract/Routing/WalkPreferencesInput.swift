/// Walking preferences.
public struct WalkPreferencesInput: Codable, Sendable {
    /// Walking speed on flat ground in metres per second, at least 0.1 (0.1 included); rejected, never clamped.
    public let speed: Double?
    /// How much worse walking is than riding for the same time, a multiplier from 0.1 to 100000; rejected, never clamped.
    public let reluctance: Double?
    /// Generalized cost added for each boarding, an integer from 0 to 1000000; rejected, never clamped.
    public let boardCost: Int?

    public init(
        speed: Double? = nil,
        reluctance: Double? = nil,
        boardCost: Int? = nil
    ) {
        self.speed = speed
        self.reluctance = reluctance
        self.boardCost = boardCost
    }
}
