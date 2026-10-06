/// One page of itineraries. An empty `itineraries` with empty `routingErrors` means the search ran and found nothing in the window: page on with `after` or widen `searchWindow`. A plan the router declines has no itineraries and the reason in `routingErrors`.
public struct PlanTripResponse: Codable, Sendable {
    public let itineraries: [Itinerary]
    public let pageInfo: PlanPageInfo
    /// Why the plan was declined; empty when it was not.
    public let routingErrors: [RoutingError]
    /// The date-time the search started from.
    public let searchDateTime: String?

    public init(
        itineraries: [Itinerary],
        pageInfo: PlanPageInfo,
        routingErrors: [RoutingError],
        searchDateTime: String? = nil
    ) {
        self.itineraries = itineraries
        self.pageInfo = pageInfo
        self.routingErrors = routingErrors
        self.searchDateTime = searchDateTime
    }
}
