public enum TransitMode: String, Codable, Sendable, CaseIterable {
    case airplane = "AIRPLANE"
    case bus = "BUS"
    case cableCar = "CABLE_CAR"
    case carpool = "CARPOOL"
    case coach = "COACH"
    case ferry = "FERRY"
    case funicular = "FUNICULAR"
    case gondola = "GONDOLA"
    case monorail = "MONORAIL"
    case rail = "RAIL"
    case snowAndIce = "SNOW_AND_ICE"
    case subway = "SUBWAY"
    case taxi = "TAXI"
    case tram = "TRAM"
    case trolleybus = "TROLLEYBUS"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TransitMode(rawValue: raw) ?? .unknown
    }
}
