public struct StopDeparturesStoptime: Codable, Sendable {
    /// Unix seconds at the start of the trip's service day; it plus a seconds field gives that time as Unix seconds.
    public let serviceDay: Int
    /// Seconds after `serviceDay`.
    public let scheduledDeparture: Int
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeDeparture: Int
    /// True when `realtimeDeparture` comes from realtime.
    public let realtime: Bool
    public let realtimeState: RealtimeState
    /// The platform or stand the departure leaves from, which tells a station's platforms apart.
    public let stop: StopDeparturesStop
    public let trip: StopDeparturesTrip
    /// The trip's usual delay at this stop in seconds: the median (p50) recorded on the service date's day type, from the environment's realtime history, never below 0 and never decreasing along the trip's pattern. Null when the trip has live realtime or there is no history.
    public let typicalDelay: Int?
    /// Null when the feed has none.
    public let headsign: String?

    public init(
        serviceDay: Int,
        scheduledDeparture: Int,
        realtimeDeparture: Int,
        realtime: Bool,
        realtimeState: RealtimeState,
        stop: StopDeparturesStop,
        trip: StopDeparturesTrip,
        typicalDelay: Int? = nil,
        headsign: String? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledDeparture = scheduledDeparture
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.stop = stop
        self.trip = trip
        self.typicalDelay = typicalDelay
        self.headsign = headsign
    }
}
