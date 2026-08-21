public struct Itinerary: Codable, Sendable {
    public let numberOfTransfers: Int
    public let legs: [Leg]
    public let start: String?
    public let end: String?
    public let duration: Int?
    public let waitingTime: Int?
    public let accessibilityScore: Double?

    public init(
        numberOfTransfers: Int,
        legs: [Leg],
        start: String? = nil,
        end: String? = nil,
        duration: Int? = nil,
        waitingTime: Int? = nil,
        accessibilityScore: Double? = nil
    ) {
        self.numberOfTransfers = numberOfTransfers
        self.legs = legs
        self.start = start
        self.end = end
        self.duration = duration
        self.waitingTime = waitingTime
        self.accessibilityScore = accessibilityScore
    }
}
