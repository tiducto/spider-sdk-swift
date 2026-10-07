/// Exactly one of `passThrough`, `visit`; neither or both is a 400 `via is invalid`.
public struct PlanViaLocationInput: Codable, Sendable {
    /// The journey passes the location, on board or by changing vehicles there.
    public let passThrough: AnyCodable?
    /// The journey stops at the location: it alights there and boards again after `minimumWaitTime`.
    public let visit: AnyCodable?

    public init(
        passThrough: AnyCodable? = nil,
        visit: AnyCodable? = nil
    ) {
        self.passThrough = passThrough
        self.visit = visit
    }
}
