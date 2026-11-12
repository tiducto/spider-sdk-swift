public struct Stoptime: Codable, Sendable {
    /// Unix seconds at the start of the trip's service day; it plus a seconds field gives that time as Unix seconds.
    public let serviceDay: Int
    /// Seconds after `serviceDay`.
    public let scheduledArrival: Int
    /// Seconds after `serviceDay`.
    public let scheduledDeparture: Int
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeArrival: Int
    /// Seconds after `serviceDay`, realtime merged in; the schedule when there is none.
    public let realtimeDeparture: Int
    /// True when `realtimeArrival` and `realtimeDeparture` come from realtime.
    public let realtime: Bool
    public let realtimeState: RealtimeState
    public let stop: TripStop
    /// Seconds of delay at the requested `reliability`: that level's percentile of the trip's recorded delay at this stop on the service date's day type, from the environment's realtime history. Never below 0. At each level, no trip arrives at a stop, delay applied, before an earlier trip of the same pattern does. Null when `reliability` is omitted, when the trip has live realtime, a canceled trip included, or when there is no history.
    public let typicalDelay: Int?
    /// How a rider boards here. Null when the stop is canceled: the trip is canceled or realtime skips the stop.
    public let pickupType: PickupDropoffType?
    /// How a rider alights here. Null when the stop is canceled: the trip is canceled or realtime skips the stop.
    public let dropoffType: PickupDropoffType?
    /// The stop time's position in the trip: increasing along it, not necessarily from 0 or consecutive. Realtime that adds or removes stops can change it.
    public let stopPosition: Int?
    /// Index into the decoded `tripGeometry` points of where this stop sits on the trip's line. Null when `tripGeometry` is null or the stop has no point on it.
    public let geometryIndex: Int?

    public init(
        serviceDay: Int,
        scheduledArrival: Int,
        scheduledDeparture: Int,
        realtimeArrival: Int,
        realtimeDeparture: Int,
        realtime: Bool,
        realtimeState: RealtimeState,
        stop: TripStop,
        typicalDelay: Int? = nil,
        pickupType: PickupDropoffType? = nil,
        dropoffType: PickupDropoffType? = nil,
        stopPosition: Int? = nil,
        geometryIndex: Int? = nil
    ) {
        self.serviceDay = serviceDay
        self.scheduledArrival = scheduledArrival
        self.scheduledDeparture = scheduledDeparture
        self.realtimeArrival = realtimeArrival
        self.realtimeDeparture = realtimeDeparture
        self.realtime = realtime
        self.realtimeState = realtimeState
        self.stop = stop
        self.typicalDelay = typicalDelay
        self.pickupType = pickupType
        self.dropoffType = dropoffType
        self.stopPosition = stopPosition
        self.geometryIndex = geometryIndex
    }
}
