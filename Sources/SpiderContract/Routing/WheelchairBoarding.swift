public enum WheelchairBoarding: String, Codable, Sendable, CaseIterable {
    case notPossible = "NOT_POSSIBLE"
    case noInformation = "NO_INFORMATION"
    case possible = "POSSIBLE"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WheelchairBoarding(rawValue: raw) ?? .unknown
    }
}
