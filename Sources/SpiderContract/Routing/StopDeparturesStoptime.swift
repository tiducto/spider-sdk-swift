public struct StopDeparturesStoptime: Codable, Sendable {
    /// Unix seconds at the start of the trip's service day; it plus a seconds field gives that time as Unix seconds.
    public let serviceDay: Int?
    /// Seconds after `serviceDay`.
    public let scheduledDeparture: Int?
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeDeparture: Int?
    /// True when `realtimeDeparture` comes from realtime.
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    /// The usual delay at this stop in seconds: the median recorded for that trip on the service date's day type, from the environment's realtime history. Null when there is no history.
    public let typicalDelay: Int?
    public let headsign: String?
    /// The platform or stand the departure leaves from, which tells a station's platforms apart.
    public let stop: StopDeparturesStop?
    public let trip: StopDeparturesTrip?

    public init(
        serviceDay: Int? = nil,
        scheduledDeparture: Int? = nil,
        realtimeDeparture: Int? = nil,
        realtime: Bool? = nil,
        realtimeState: RealtimeState? = nil,
        typicalDelay: Int? = nil,
        headsign: String? = nil,
        stop: StopDeparturesStop? = nil,
        trip: StopDeparturesTrip? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledDeparture = scheduledDeparture
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.typicalDelay = typicalDelay
        self.headsign = headsign
        self.stop = stop
        self.trip = trip
    }
}
