public struct StopDeparturesStoptime: Codable, Sendable {
    public let serviceDay: Int?
    public let scheduledDeparture: Int?
    public let realtimeDeparture: Int?
    public let realtime: Bool?
    public let realtimeState: RealtimeState?
    /// Typical (p50) delay at this stop in seconds for this trip on the service date's day type; null when unknown.
    public let typicalDelay: Int?
    public let headsign: String?
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
