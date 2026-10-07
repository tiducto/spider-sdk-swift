/// One page of itineraries. An empty `itineraries` with empty `routingErrors` means the search ran and found nothing in the window. A plan the router declines has the reason in `routingErrors`; with `NO_STOPS_IN_RANGE` or `NO_TRANSIT_CONNECTION`, `itineraries` holds the direct walk when one exists, and is empty otherwise.
public struct PlanTripResponse: Codable, Sendable {
    public let itineraries: [Itinerary]
    public let pageInfo: PlanPageInfo
    /// Why the plan was declined; empty when it was not.
    public let routingErrors: [RoutingError]
    /// The date-time the search started from; with a cursor, the cursor's.
    public let searchDateTime: String

    public init(
        itineraries: [Itinerary],
        pageInfo: PlanPageInfo,
        routingErrors: [RoutingError],
        searchDateTime: String
    ) {
        self.itineraries = itineraries
        self.pageInfo = pageInfo
        self.routingErrors = routingErrors
        self.searchDateTime = searchDateTime
    }
}
