/// One journey, leg by leg. Times are in the feed's time zone.
public struct Itinerary: Codable, Sendable {
    public let start: String
    public let end: String
    /// Seconds from `start` to `end`.
    public let duration: Int
    /// Seconds spent waiting at stops.
    public let waitingTime: Int
    /// Changes between vehicles. Staying on board as the vehicle carries on as another trip (`interlineWithPreviousLeg`) is not counted.
    public let numberOfTransfers: Int
    public let legs: [Leg]

    public init(
        start: String,
        end: String,
        duration: Int,
        waitingTime: Int,
        numberOfTransfers: Int,
        legs: [Leg]
    ) {
        self.start = start
        self.end = end
        self.duration = duration
        self.waitingTime = waitingTime
        self.numberOfTransfers = numberOfTransfers
        self.legs = legs
    }
}
