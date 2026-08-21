public enum InputField: String, Codable, Sendable, CaseIterable {
    case dateTime = "DATE_TIME"
    case from = "FROM"
    case to = "TO"
    case via = "VIA"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = InputField(rawValue: raw) ?? .unknown
    }
}
