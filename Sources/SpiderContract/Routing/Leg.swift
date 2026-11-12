/// One walk or ride.
public struct Leg: Codable, Sendable {
    public let mode: Mode
    public let start: LegTime
    public let end: LegTime
    /// The realtime state of the leg's trip; `SCHEDULED` on a walk leg.
    public let realtimeState: RealtimeState
    /// True when the leg's times include realtime.
    public let realTime: Bool
    public let from: Place
    public let to: Place
    /// Metres.
    public let distance: Double
    /// Seconds.
    public let duration: Int
    /// How the rider boards the leg's trip at `from`. `SCHEDULED` on a walk leg and on a leg with `interlineWithPreviousLeg`, where the rider is already on board.
    public let pickupType: PickupDropoffType
    /// How the rider alights from the leg's trip at `to`. `SCHEDULED` on a walk leg and on a leg the next leg continues with `interlineWithPreviousLeg`, where the rider stays on board.
    public let dropoffType: PickupDropoffType
    /// True on a transit leg ridden in the same vehicle as the previous leg: the vehicle carries on as another trip, often under another line number, and the rider stays on board. That change is not counted in `numberOfTransfers`. False on every other leg.
    public let interlineWithPreviousLeg: Bool
    public let legGeometry: Geometry
    /// Seconds of delay applied to this leg's arrival at the requested `reliability`: that level's percentile of the trip's recorded delay at the alighting stop on the service date's day type, from the environment's realtime history. Never below 0. At each level, no trip arrives at a stop, delay applied, before an earlier trip of the same pattern does. Null when `reliability` is omitted, when the trip has live realtime, a canceled trip included, or when there is no history, and on a walk leg.
    public let typicalArrivalDelay: Int?
    /// The GTFS service date of the leg's trip, `YYYY-MM-DD`; null on a walk leg.
    public let serviceDate: String?
    /// Null on a walk leg.
    public let route: Route?
    /// Null on a walk leg and when the feed has none.
    public let headsign: String?
    /// Null on a walk leg.
    public let trip: Trip?

    public init(
        mode: Mode,
        start: LegTime,
        end: LegTime,
        realtimeState: RealtimeState,
        realTime: Bool,
        from: Place,
        to: Place,
        distance: Double,
        duration: Int,
        pickupType: PickupDropoffType,
        dropoffType: PickupDropoffType,
        interlineWithPreviousLeg: Bool,
        legGeometry: Geometry,
        typicalArrivalDelay: Int? = nil,
        serviceDate: String? = nil,
        route: Route? = nil,
        headsign: String? = nil,
        trip: Trip? = nil
    ) {
        self.mode = mode
        self.start = start
        self.end = end
        self.realtimeState = realtimeState
        self.realTime = realTime
        self.from = from
        self.to = to
        self.distance = distance
        self.duration = duration
        self.pickupType = pickupType
        self.dropoffType = dropoffType
        self.interlineWithPreviousLeg = interlineWithPreviousLeg
        self.legGeometry = legGeometry
        self.typicalArrivalDelay = typicalArrivalDelay
        self.serviceDate = serviceDate
        self.route = route
        self.headsign = headsign
        self.trip = trip
    }
}
