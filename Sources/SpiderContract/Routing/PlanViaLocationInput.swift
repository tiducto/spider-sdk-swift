/// Exactly one of `passThrough`, `visit`; neither or both is a 400 `via is invalid`.
public struct PlanViaLocationInput: Codable, Sendable {
    /// The journey passes the location: on board, alighting there, or starting there. A stop where the vehicle does not let passengers off is not passed on board, and walking there to board is not a pass.
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
