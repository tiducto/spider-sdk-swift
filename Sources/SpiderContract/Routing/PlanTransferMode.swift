public enum PlanTransferMode: String, Codable, Sendable, CaseIterable {
    case bicycle = "BICYCLE"
    case car = "CAR"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlanTransferMode(rawValue: raw) ?? .unknown
    }
}
