/// A location the journey passes.
public struct PlanPassThroughViaLocationInput: Codable, Sendable {
    /// 1 to 10 feed-prefixed stop or station ids; passing any one of them is enough. More, or none, is a 400 naming `via`.
    public let stopLocationIds: [String]

    public init(
        stopLocationIds: [String]
    ) {
        self.stopLocationIds = stopLocationIds
    }
}
