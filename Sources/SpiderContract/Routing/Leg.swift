public struct Leg: Codable, Sendable {
    public let start: LegTime
    public let end: LegTime
    public let from: Place
    public let to: Place
    public let mode: Mode?
    /// Delay in seconds applied to this leg's arrival at the requested `reliability`; null when omitted or unknown.
    public let typicalArrivalDelay: Int?
    public let realtimeState: RealtimeState?
    public let realTime: Bool?
    public let serviceDate: String?
    public let route: Route?
    public let headsign: String?
    public let distance: Double?
    public let duration: Double?
    public let accessibilityScore: Double?
    public let trip: Trip?
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
        accessibilityScore: Double? = nil,
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
        self.accessibilityScore = accessibilityScore
        self.trip = trip
        self.interlineWithPreviousLeg = interlineWithPreviousLeg
        self.legGeometry = legGeometry
    }
}
