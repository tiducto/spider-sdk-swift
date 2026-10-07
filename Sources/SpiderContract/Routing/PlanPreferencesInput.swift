/// Routing preferences. An absent member keeps the environment's default.
public struct PlanPreferencesInput: Codable, Sendable {
    public let street: AnyCodable?
    public let transit: AnyCodable?
    public let accessibility: AnyCodable?

    public init(
        street: AnyCodable? = nil,
        transit: AnyCodable? = nil,
        accessibility: AnyCodable? = nil
    ) {
        self.street = street
        self.transit = transit
        self.accessibility = accessibility
    }
}
