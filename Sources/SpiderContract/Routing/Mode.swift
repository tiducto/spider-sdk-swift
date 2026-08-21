public enum Mode: String, Codable, Sendable, CaseIterable {
    case airplane = "AIRPLANE"
    case bicycle = "BICYCLE"
    case bus = "BUS"
    case cableCar = "CABLE_CAR"
    case car = "CAR"
    case carpool = "CARPOOL"
    case coach = "COACH"
    case ferry = "FERRY"
    case flex = "FLEX"
    case flexible = "FLEXIBLE"
    case funicular = "FUNICULAR"
    case gondola = "GONDOLA"
    case legSwitch = "LEG_SWITCH"
    case monorail = "MONORAIL"
    case rail = "RAIL"
    case scooter = "SCOOTER"
    case subway = "SUBWAY"
    case taxi = "TAXI"
    case tram = "TRAM"
    case transit = "TRANSIT"
    case trolleybus = "TROLLEYBUS"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Mode(rawValue: raw) ?? .unknown
    }
}
