/// A location the journey stops at.
public struct PlanVisitViaLocationInput: Codable, Sendable {
    /// 1 to 10 feed-prefixed stop or station ids; visiting any one of them is enough. Absent, empty, or more than 10 is a 400 naming `via`.
    public let stopLocationIds: [String]?
    /// Least time to stay at the location, as an ISO-8601 duration: `PT0S` to `PT1H`; rejected, never clamped. Absent means `PT0S`.
    public let minimumWaitTime: String?

    public init(
        stopLocationIds: [String]? = nil,
        minimumWaitTime: String? = nil
    ) {
        self.stopLocationIds = stopLocationIds
        self.minimumWaitTime = minimumWaitTime
    }
}
