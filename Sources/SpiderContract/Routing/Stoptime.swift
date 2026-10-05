public struct Stoptime: Codable, Sendable {
    public let serviceDay: Int?
    public let scheduledArrival: Int?
    public let scheduledDeparture: Int?
    public let realtimeArrival: Int?
    public let realtimeDeparture: Int?
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    /// Typical (p50) delay at this stop in seconds for this trip on the service date's day type; null when unknown.
    public let typicalDelay: Int?
    public let stop: TripStop?

    public init(
        serviceDay: Int? = nil,
        scheduledArrival: Int? = nil,
        scheduledDeparture: Int? = nil,
        realtimeArrival: Int? = nil,
        realtimeDeparture: Int? = nil,
        realtime: Bool? = nil,
        realtimeState: RealtimeState? = nil,
        typicalDelay: Int? = nil,
        stop: TripStop? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledArrival = scheduledArrival
        self.scheduledDeparture = scheduledDeparture
        self.realtimeArrival = realtimeArrival
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.typicalDelay = typicalDelay
        self.stop = stop
    }
}
