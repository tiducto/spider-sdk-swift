public enum PlanEgressMode: String, Codable, Sendable, CaseIterable {
    case bicycle = "BICYCLE"
    case bicycleRental = "BICYCLE_RENTAL"
    case car = "CAR"
    case carPickup = "CAR_PICKUP"
    case carRental = "CAR_RENTAL"
    case flex = "FLEX"
    case scooterRental = "SCOOTER_RENTAL"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlanEgressMode(rawValue: raw) ?? .unknown
    }
}
