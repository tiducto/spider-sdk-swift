/// Street preferences, for walking to, from and between stops.
public struct PlanStreetPreferencesInput: Codable, Sendable {
    public let walk: AnyCodable?

    public init(
        walk: AnyCodable? = nil
    ) {
        self.walk = walk
    }
}
