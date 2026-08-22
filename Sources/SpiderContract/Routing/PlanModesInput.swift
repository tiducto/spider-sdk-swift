public struct PlanModesInput: Codable, Sendable {
    public let direct: [PlanDirectMode]?
    public let directOnly: Bool?
    public let transit: PlanTransitModesInput?
    public let transitOnly: Bool?

    public init(
        direct: [PlanDirectMode]? = nil,
        directOnly: Bool? = nil,
        transit: PlanTransitModesInput? = nil,
        transitOnly: Bool? = nil
    ) {
        self.direct = direct
        self.directOnly = directOnly
        self.transit = transit
        self.transitOnly = transitOnly
    }
}
