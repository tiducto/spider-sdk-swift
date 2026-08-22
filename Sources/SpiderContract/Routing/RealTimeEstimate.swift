public struct RealTimeEstimate: Codable, Sendable {
    public let time: String
    public let delay: String

    public init(
        time: String,
        delay: String
    ) {
        self.time = time
        self.delay = delay
    }
}
