/// The station a stop belongs to (GTFS `parent_station`, a `location_type` 1 stop). Its `gtfsId` is a station id that plan's `stopLocationId` and departures' `id` accept.
public struct ParentStation: Codable, Sendable {
    public let gtfsId: String
    public let name: String

    public init(
        gtfsId: String,
        name: String
    ) {
        self.gtfsId = gtfsId
        self.name = name
    }
}
