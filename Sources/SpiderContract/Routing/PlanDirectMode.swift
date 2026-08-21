public enum PlanDirectMode: String, Codable, Sendable, CaseIterable {
    case bicycle = "BICYCLE"
    case bicycleParking = "BICYCLE_PARKING"
    case bicycleRental = "BICYCLE_RENTAL"
    case car = "CAR"
    case carParking = "CAR_PARKING"
    case carRental = "CAR_RENTAL"
    case flex = "FLEX"
    case scooterRental = "SCOOTER_RENTAL"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlanDirectMode(rawValue: raw) ?? .unknown
    }
}
