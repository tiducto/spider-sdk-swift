public struct PlanViaLocationInput: Codable, Sendable {
    public let passThrough: PlanPassThroughViaLocationInput?
    public let visit: PlanVisitViaLocationInput?

    public init(
        passThrough: PlanPassThroughViaLocationInput? = nil,
        visit: PlanVisitViaLocationInput? = nil
    ) {
        self.passThrough = passThrough
        self.visit = visit
    }
}
