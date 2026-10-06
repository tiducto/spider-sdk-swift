public struct Stoptime: Codable, Sendable {
    /// Unix seconds at the start of the trip's service day; it plus a seconds field gives that time as Unix seconds.
    public let serviceDay: Int?
    /// Seconds after `serviceDay`.
    public let scheduledArrival: Int?
    /// Seconds after `serviceDay`.
    public let scheduledDeparture: Int?
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeArrival: Int?
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeDeparture: Int?
    /// True when `realtimeArrival` and `realtimeDeparture` come from realtime.
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    /// The usual delay at this stop in seconds: the median recorded for that trip on the service date's day type, from the environment's realtime history. Null when there is no history.
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
