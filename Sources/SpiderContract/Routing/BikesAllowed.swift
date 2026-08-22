public enum BikesAllowed: String, Codable, Sendable, CaseIterable {
    case allowed = "ALLOWED"
    case notAllowed = "NOT_ALLOWED"
    case noInformation = "NO_INFORMATION"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BikesAllowed(rawValue: raw) ?? .unknown
    }
}
