public struct WalkPreferencesInput: Codable, Sendable {
    public let boardCost: Int?
    public let reluctance: Double?
    public let safetyFactor: Double?
    public let speed: Double?

    public init(
        boardCost: Int? = nil,
        reluctance: Double? = nil,
        safetyFactor: Double? = nil,
        speed: Double? = nil
    ) {
        self.boardCost = boardCost
        self.reluctance = reluctance
        self.safetyFactor = safetyFactor
        self.speed = speed
    }
}
