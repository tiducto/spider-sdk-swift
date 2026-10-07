/// Which modes the search may use. `directOnly` and `transitOnly` together are a 400 `modes is invalid`.
public struct PlanModesInput: Codable, Sendable {
    /// Only a direct walk, without transit. A direct-only plan has no pages: its cursors are null.
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
