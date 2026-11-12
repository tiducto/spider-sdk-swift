public struct StopDeparturesStoptime: Codable, Sendable {
    /// Unix seconds at the start of the trip's service day; it plus a seconds field gives that time as Unix seconds.
    public let serviceDay: Int
    /// The GTFS service date of the departure's trip, `YYYY-MM-DD`, as `Leg.serviceDate`. For a departure past 24:00 of its service day, it is the day before the departure's calendar date.
    public let serviceDate: String
    /// Seconds after `serviceDay`.
    public let scheduledDeparture: Int
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeDeparture: Int
    /// True when `realtimeDeparture` comes from realtime.
    public let realtime: Bool
    public let realtimeState: RealtimeState
    /// How a rider boards here. Never `NONE`: the board leaves out departures nobody can board.
    public let pickupType: PickupDropoffType
    /// How a rider alights here.
    public let dropoffType: PickupDropoffType
    /// The platform or stand the departure leaves from, which tells a station's platforms apart.
    public let stop: StopDeparturesStop
    public let trip: StopDeparturesTrip
    /// Seconds of delay at the requested `reliability`: that level's percentile of the trip's recorded delay at this stop on the service date's day type, from the environment's realtime history. Never below 0. At each level, no trip arrives at a stop, delay applied, before an earlier trip of the same pattern does. Null when `reliability` is omitted, when the trip has live realtime, a canceled trip included, or when there is no history.
    public let typicalDelay: Int?
    /// Null when the feed has none.
    public let headsign: String?
    /// The position in the trip of this departure, as the trip's `stopPosition`.
    public let stopPosition: Int?

    public init(
        serviceDay: Int,
        serviceDate: String,
        scheduledDeparture: Int,
        realtimeDeparture: Int,
        realtime: Bool,
        realtimeState: RealtimeState,
        pickupType: PickupDropoffType,
        dropoffType: PickupDropoffType,
        stop: StopDeparturesStop,
        trip: StopDeparturesTrip,
        typicalDelay: Int? = nil,
        headsign: String? = nil,
        stopPosition: Int? = nil
    ) {
        self.serviceDay = serviceDay
        self.serviceDate = serviceDate
        self.scheduledDeparture = scheduledDeparture
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.pickupType = pickupType
        self.dropoffType = dropoffType
        self.stop = stop
        self.trip = trip
        self.typicalDelay = typicalDelay
        self.headsign = headsign
        self.stopPosition = stopPosition
    }
}
