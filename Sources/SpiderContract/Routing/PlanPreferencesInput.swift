public struct PlanPreferencesInput: Codable, Sendable {
    public let accessibility: AccessibilityPreferencesInput?
    public let street: PlanStreetPreferencesInput?
    public let transit: TransitPreferencesInput?

    public init(
        accessibility: AccessibilityPreferencesInput? = nil,
        street: PlanStreetPreferencesInput? = nil,
        transit: TransitPreferencesInput? = nil
    ) {
        self.accessibility = accessibility
        self.street = street
        self.transit = transit
    }
}
