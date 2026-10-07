public struct LegTime: Codable, Sendable {
    public let scheduledTime: String
    /// Null without realtime.
    public let estimated: AnyCodable

    public init(
        scheduledTime: String,
        estimated: AnyCodable
    ) {
        self.scheduledTime = scheduledTime
        self.estimated = estimated
    }
}
