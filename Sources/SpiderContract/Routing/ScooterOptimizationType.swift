public enum ScooterOptimizationType: String, Codable, Sendable, CaseIterable {
    case flatStreets = "FLAT_STREETS"
    case safestStreets = "SAFEST_STREETS"
    case safeStreets = "SAFE_STREETS"
    case shortestDuration = "SHORTEST_DURATION"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ScooterOptimizationType(rawValue: raw) ?? .unknown
    }
}
