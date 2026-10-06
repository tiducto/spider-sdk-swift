/// Which modes the search may use.
public struct PlanModesInput: Codable, Sendable {
    /// Only a direct walk, without transit.
    public let directOnly: Bool?
    /// Never a journey without a transit leg.
    public let transitOnly: Bool?
    public let transit: PlanTransitModesInput?

    public init(
        directOnly: Bool? = nil,
        transitOnly: Bool? = nil,
        transit: PlanTransitModesInput? = nil
    ) {
        self.directOnly = directOnly
        self.transitOnly = transitOnly
        self.transit = transit
    }
}
