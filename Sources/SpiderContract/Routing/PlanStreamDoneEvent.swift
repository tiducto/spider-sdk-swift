/// The search work this stream used; ends the stream. `stoppedBy` is `targetResults` (enough itineraries sent), `maxWindow` (the whole window searched), `directOnly` (a direct-only plan, which searches no transit) or `rejected` (a declined plan, one with no stops in range or no transit connection included); new values may be added.
public struct PlanStreamDoneEvent: Codable, Sendable {
    /// Search iterations used.
    public let iterations: Int
    /// Seconds of the window searched.
    public let windowSeconds: Int
    /// Itineraries sent.
    public let resultCount: Int
    /// Why the stream stopped.
    public let stoppedBy: String

    public init(
        iterations: Int,
        windowSeconds: Int,
        resultCount: Int,
        stoppedBy: String
    ) {
        self.iterations = iterations
        self.windowSeconds = windowSeconds
        self.resultCount = resultCount
        self.stoppedBy = stoppedBy
    }
}
