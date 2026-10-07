/// A location the journey passes.
public struct PlanPassThroughViaLocationInput: Codable, Sendable {
    /// 1 to 10 feed-prefixed stop or station ids; passing any one of them is enough. Absent is a 400 `via.passThrough.stopLocationIds is required`, and empty or more than 10 `via.passThrough.stopLocationIds is out of range`.
    public let stopLocationIds: [String]

    public init(
        stopLocationIds: [String]
    ) {
        self.stopLocationIds = stopLocationIds
    }
}
