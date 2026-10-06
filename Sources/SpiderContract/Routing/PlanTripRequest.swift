/// POST body for `/routing/plan`: one page of itineraries. Paging: `before` and `after` are exclusive. Use `first` with `after` or with no cursor, and `last` only with `before`. The next page is the same body plus `after` (the page's `pageInfo.endCursor`), sized by `first`. The previous page is the same body without `first` and `after`, plus `before` (`pageInfo.startCursor`), sized by `last`. Any other pairing is a 400 naming the member that breaks it. A key not listed here, at any depth, is a 400 `<path> is not allowed`. Every bound is rejected, never clamped. `null` on an optional member means absent.
public struct PlanTripRequest: Codable, Sendable {
    public let dateTime: PlanDateTimeInput
    /// Where the journey starts. An unknown stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `FROM`.
    public let origin: PlanLabeledLocationInput
    /// Where the journey ends. An unknown stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `TO`.
    public let destination: PlanLabeledLocationInput
    /// How much time after `dateTime` the search covers (before it, for `latestArrival`), as an ISO-8601 duration such as `PT2H`: above zero and at most the environment's search-window limit; rejected, never clamped.
    public let searchWindow: String
    /// Locations the journey must visit or pass through, in the order given. How many a request takes is an environment setting, and an environment set to 0 has via turned off; more is a 400 naming `via`. An unknown via stop id is a 200 with the `routingErrors` code `LOCATION_NOT_FOUND` on `VIA`.
    public let via: [PlanViaLocationInput]?
    public let modes: PlanModesInput?
    public let preferences: PlanPreferencesInput?
    /// Itineraries on this page: 1 up to the environment's itinerary limit; rejected, never clamped. Absent means the limit. With `after` or no cursor, never with `before`.
    public let first: Int?
    /// Itineraries on the previous page: 1 up to the environment's itinerary limit; rejected, never clamped. Absent means the limit. Only with `before`.
    public let last: Int?
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
        searchWindow: String,
        via: [PlanViaLocationInput]? = nil,
        modes: PlanModesInput? = nil,
        preferences: PlanPreferencesInput? = nil,
        first: Int? = nil,
        last: Int? = nil,
        before: String? = nil,
        after: String? = nil,
        reliability: Reliability? = nil
    ) {
        self.dateTime = dateTime
        self.origin = origin
        self.destination = destination
        self.searchWindow = searchWindow
        self.via = via
        self.modes = modes
        self.preferences = preferences
        self.first = first
        self.last = last
        self.before = before
        self.after = after
        self.reliability = reliability
    }
}
