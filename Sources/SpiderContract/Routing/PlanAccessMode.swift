public enum PlanAccessMode: String, Codable, Sendable, CaseIterable {
    case bicycle = "BICYCLE"
    case bicycleParking = "BICYCLE_PARKING"
    case bicycleRental = "BICYCLE_RENTAL"
    case car = "CAR"
    case carDropOff = "CAR_DROP_OFF"
    case carParking = "CAR_PARKING"
    case carRental = "CAR_RENTAL"
    case flex = "FLEX"
    case scooterRental = "SCOOTER_RENTAL"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlanAccessMode(rawValue: raw) ?? .unknown
    }
}
