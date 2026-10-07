/// Street preferences, for walking to, from and between stops.
public struct PlanStreetPreferencesInput: Codable, Sendable {
    public let walk: WalkPreferencesInput?

    public init(
        walk: WalkPreferencesInput? = nil
    ) {
        self.walk = walk
    }
}
