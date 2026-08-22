public enum RoutingErrorCode: String, Codable, Sendable, CaseIterable {
    case locationNotFound = "LOCATION_NOT_FOUND"
    case noStopsInRange = "NO_STOPS_IN_RANGE"
    case noTransitConnection = "NO_TRANSIT_CONNECTION"
    case noTransitConnectionInSearchWindow = "NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW"
    case outsideBounds = "OUTSIDE_BOUNDS"
    case outsideServicePeriod = "OUTSIDE_SERVICE_PERIOD"
    case walkingBetterThanTransit = "WALKING_BETTER_THAN_TRANSIT"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RoutingErrorCode(rawValue: raw) ?? .unknown
    }
}
