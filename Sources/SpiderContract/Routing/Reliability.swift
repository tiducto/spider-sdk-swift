/// Delay level: `STANDARD`, `SAFE` and `VERY_SAFE` are the p50, p70 and p90 of the trip's recorded delay at a stop, on the service date's day type, from the environment's realtime history. Omitted means the timetable, on every operation.
public enum Reliability: String, Codable, Sendable, CaseIterable {
    case standard = "STANDARD"
    case safe = "SAFE"
    case verySafe = "VERY_SAFE"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Reliability(rawValue: raw) ?? .unknown
    }
}
