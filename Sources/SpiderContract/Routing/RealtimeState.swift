public enum RealtimeState: String, Codable, Sendable, CaseIterable {
    case added = "ADDED"
    case canceled = "CANCELED"
    case modified = "MODIFIED"
    case scheduled = "SCHEDULED"
    case updated = "UPDATED"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RealtimeState(rawValue: raw) ?? .unknown
    }
}
