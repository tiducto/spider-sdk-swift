public struct PlanTransitModePreferenceInput: Codable, Sendable {
    public let mode: TransitMode
    public let cost: TransitModePreferenceCostInput?

    public init(
        mode: TransitMode,
        cost: TransitModePreferenceCostInput? = nil
    ) {
        self.mode = mode
        self.cost = cost
    }
}
