/// Exactly one of `passThrough`, `visit`.
public struct PlanViaLocationInput: Codable, Sendable {
    /// The journey passes the location, on board or by changing vehicles there.
    public let passThrough: PlanPassThroughViaLocationInput?
    /// The journey stops at the location: it alights there and boards again after `minimumWaitTime`.
    public let visit: PlanVisitViaLocationInput?

    public init(
        passThrough: PlanPassThroughViaLocationInput? = nil,
        visit: PlanVisitViaLocationInput? = nil
    ) {
        self.passThrough = passThrough
        self.visit = visit
    }
}
