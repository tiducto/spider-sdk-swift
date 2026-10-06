/// POST body for `/routing/plan-stream`: the Plan Trip search, streamed. Instead of a fixed window, the stream widens its search until it has sent `targetResults` itineraries or has searched `maxWindow`. To continue, send the `pageInfo` event's `endCursor` as `after` (later) or its `startCursor` as `before` (earlier); `before` and `after` are exclusive. A key not listed here, at any depth, is a 400 `<path> is not allowed`. Every bound is rejected, never clamped. `null` on an optional member means absent.
public struct PlanStreamRequest: Codable, Sendable {
    public let dateTime: PlanDateTimeInput
    /// Where the journey starts. An unknown stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `FROM`.
    public let origin: PlanLabeledLocationInput
    /// Where the journey ends. An unknown stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `TO`.
    public let destination: PlanLabeledLocationInput
    /// The stream stops once it has sent this many itineraries: 1 up to the environment's itinerary limit; rejected, never clamped.
    public let targetResults: Int
    /// The stream stops once it has searched this far past `dateTime` (before it, for `latestArrival`), as an ISO-8601 duration: at least `PT2H` and at most the environment's search-window limit; rejected, never clamped.
    public let maxWindow: String
    /// Locations the journey must visit or pass through, in the order given. How many a request takes is an environment setting, and an environment set to 0 has via turned off; more is a 400 naming `via`. An unknown via stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `VIA`.
    public let via: [PlanViaLocationInput]?
    public let modes: PlanModesInput?
    public let preferences: PlanPreferencesInput?
    /// `pageInfo.startCursor` of a page, to fetch the page before it. Never with `after`.
    public let before: String?
    /// `pageInfo.endCursor` of a page, to fetch the page after it. Never with `before`.
    public let after: String?
    /// Delay-aware planning level; omitted or null plans on the timetable alone.
    public let reliability: Reliability?

    public init(
        dateTime: PlanDateTimeInput,
        origin: PlanLabeledLocationInput,
        destination: PlanLabeledLocationInput,
        targetResults: Int,
        maxWindow: String,
        via: [PlanViaLocationInput]? = nil,
        modes: PlanModesInput? = nil,
        preferences: PlanPreferencesInput? = nil,
        before: String? = nil,
        after: String? = nil,
        reliability: Reliability? = nil
    ) {
        self.dateTime = dateTime
        self.origin = origin
        self.destination = destination
        self.targetResults = targetResults
        self.maxWindow = maxWindow
        self.via = via
        self.modes = modes
        self.preferences = preferences
        self.before = before
        self.after = after
        self.reliability = reliability
    }
}
