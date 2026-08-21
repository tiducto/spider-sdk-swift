public struct TripStoptime: Codable, Sendable {
    public let serviceDay: Int?
    public let scheduledArrival: Int?
    public let scheduledDeparture: Int?
    public let realtimeArrival: Int?
    public let realtimeDeparture: Int?
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    public let stop: TripStop?

    public init(
        serviceDay: Int? = nil,
        scheduledArrival: Int? = nil,
        scheduledDeparture: Int? = nil,
        realtimeArrival: Int? = nil,
        realtimeDeparture: Int? = nil,
        realtime: Bool? = nil,
        realtimeState: RealtimeState? = nil,
        stop: TripStop? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledArrival = scheduledArrival
        self.scheduledDeparture = scheduledDeparture
        self.realtimeArrival = realtimeArrival
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.stop = stop
    }
}
