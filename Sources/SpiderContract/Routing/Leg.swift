/// One walk or ride.
public struct Leg: Codable, Sendable {
    public let mode: Mode
    public let start: LegTime
    public let end: LegTime
    /// Seconds of delay applied to this leg's arrival at the requested `reliability`: that level's percentile (p50, p70 or p90) of the trip's recorded delay at the alighting stop on the service date's day type, from the environment's realtime history, never below 0 and never decreasing along the trip's pattern. Null when `reliability` is omitted, the trip has live realtime or there is no history, and on a walk leg.
    public let typicalArrivalDelay: Int
    public let realtimeState: RealtimeState
    /// True when the leg's times include realtime.
    public let realTime: Bool
    /// The GTFS service date of the leg's trip, `YYYY-MM-DD`; null on a walk leg.
    public let serviceDate: String
    public let from: Place
    public let to: Place
    /// Null on a walk leg.
    public let route: AnyCodable
    /// Null on a walk leg and when the feed has none.
    public let headsign: String
    /// Metres.
    public let distance: Double
    /// Seconds.
    public let duration: Int
    /// Null on a walk leg.
    public let trip: AnyCodable
    /// True on a transit leg ridden in the same vehicle as the previous leg: the vehicle carries on as another trip, often under another line number, and the rider stays on board. That change is not counted in `numberOfTransfers`. False on every other leg.
    public let interlineWithPreviousLeg: Bool
    public let legGeometry: Geometry

    public init(
        mode: Mode,
        start: LegTime,
        end: LegTime,
        typicalArrivalDelay: Int,
        realtimeState: RealtimeState,
        realTime: Bool,
        serviceDate: String,
        from: Place,
        to: Place,
        route: AnyCodable,
        headsign: String,
        distance: Double,
        duration: Int,
        trip: AnyCodable,
        interlineWithPreviousLeg: Bool,
        legGeometry: Geometry
    ) {
        self.mode = mode
        self.start = start
        self.end = end
        self.typicalArrivalDelay = typicalArrivalDelay
        self.realtimeState = realtimeState
        self.realTime = realTime
        self.serviceDate = serviceDate
        self.from = from
        self.to = to
        self.route = route
        self.headsign = headsign
        self.distance = distance
        self.duration = duration
        self.trip = trip
        self.interlineWithPreviousLeg = interlineWithPreviousLeg
        self.legGeometry = legGeometry
    }
}
