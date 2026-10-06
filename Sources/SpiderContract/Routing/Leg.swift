/// One walk or ride.
public struct Leg: Codable, Sendable {
    public let start: LegTime
    public let end: LegTime
    public let from: Place
    public let to: Place
    public let mode: Mode?
    /// Seconds of delay applied to this leg's arrival at the requested `reliability`: that trip's typical delay at the stop on the service date's day type, from the environment's realtime history. Null when `reliability` is omitted or there is no history.
    public let typicalArrivalDelay: Int?
    public let realtimeState: RealtimeState?
    /// True when the leg's times include realtime.
    public let realTime: Bool?
    /// The GTFS service date of the leg's trip, `YYYY-MM-DD`; null on a walk leg.
    public let serviceDate: String?
    /// Null on a walk leg.
    public let route: Route?
    public let headsign: String?
    /// Metres.
    public let distance: Double?
    /// Seconds.
    public let duration: Double?
    /// Null on a walk leg.
    public let trip: Trip?
    /// True on a transit leg ridden in the same vehicle as the previous leg: the vehicle carries on as another trip, often under another line number, and the rider stays on board. That change is not counted in `numberOfTransfers`. False on every other leg.
    public let interlineWithPreviousLeg: Bool?
    public let legGeometry: Geometry?

    public init(
        start: LegTime,
        end: LegTime,
        from: Place,
        to: Place,
        mode: Mode? = nil,
        typicalArrivalDelay: Int? = nil,
        realtimeState: RealtimeState? = nil,
        realTime: Bool? = nil,
        serviceDate: String? = nil,
        route: Route? = nil,
        headsign: String? = nil,
        distance: Double? = nil,
        duration: Double? = nil,
        trip: Trip? = nil,
        interlineWithPreviousLeg: Bool? = nil,
        legGeometry: Geometry? = nil
    ) {
        self.start = start
        self.end = end
        self.from = from
        self.to = to
        self.mode = mode
        self.typicalArrivalDelay = typicalArrivalDelay
        self.realtimeState = realtimeState
        self.realTime = realTime
        self.serviceDate = serviceDate
        self.route = route
        self.headsign = headsign
        self.distance = distance
        self.duration = duration
        self.trip = trip
        self.interlineWithPreviousLeg = interlineWithPreviousLeg
        self.legGeometry = legGeometry
    }
}
