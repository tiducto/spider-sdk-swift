/// POST body for `/routing/trip`. A key not listed here is a 400 `<key> is not allowed`.
public struct TripRequest: Codable, Sendable {
    /// Feed-prefixed trip id (`<feedId>:<id>`).
    public let id: String
    /// The service date, `YYYY-MM-DD` (`YYYYMMDD` also works). Absent means today in the feed's time zone. A value that is not a real date is a 400 naming `serviceDate`.
    public let serviceDate: String?

    public init(
        id: String,
        serviceDate: String? = nil
    ) {
        self.id = id
        self.serviceDate = serviceDate
    }
}
