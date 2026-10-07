/// POST body for `/routing/v1/departures`. A key not listed here is a 400 `<key> is not allowed`, whatever its value, null included. Every bound is rejected, never clamped. `null` on an optional member means absent, and on a required member is a 400 `<path> is required`.
public struct DeparturesRequest: Codable, Sendable {
    /// Feed-prefixed id (`<feedId>:<id>`) of a stop, for that platform's board, or of a station, for all its platforms. A bare or foreign-prefixed id resolves to nothing, and `stop` is null.
    public let id: String
    /// Most rows on the board: 1 up to the environment's limit; rejected, never clamped.
    public let numberOfDepartures: Int
    /// Seconds after `startTime` the board covers: 1 to 86400 (24 hours); rejected, never clamped.
    public let timeRange: Int
    /// Unix seconds the board starts at, from 0 to 4102444799 (2099-12-31T23:59:59Z). Absent or 0 means now.
    public let startTime: Int?

    public init(
        id: String,
        numberOfDepartures: Int,
        timeRange: Int,
        startTime: Int? = nil
    ) {
        self.id = id
        self.numberOfDepartures = numberOfDepartures
        self.timeRange = timeRange
        self.startTime = startTime
    }
}
