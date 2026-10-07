/// A transit mode the search may use.
public struct PlanTransitModePreferenceInput: Codable, Sendable {
    public let mode: TransitMode
    public let cost: AnyCodable?

    public init(
        mode: TransitMode,
        cost: AnyCodable? = nil
    ) {
        self.mode = mode
        self.cost = cost
    }
}
