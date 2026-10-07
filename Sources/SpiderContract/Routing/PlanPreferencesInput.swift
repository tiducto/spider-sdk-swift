/// Routing preferences. An absent member keeps the environment's default.
public struct PlanPreferencesInput: Codable, Sendable {
    public let street: PlanStreetPreferencesInput?
    public let transit: TransitPreferencesInput?
    public let accessibility: AccessibilityPreferencesInput?

    public init(
        street: PlanStreetPreferencesInput? = nil,
        transit: TransitPreferencesInput? = nil,
        accessibility: AccessibilityPreferencesInput? = nil
    ) {
        self.street = street
        self.transit = transit
        self.accessibility = accessibility
    }
}
