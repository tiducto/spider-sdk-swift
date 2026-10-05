import Foundation

// The public, consumer-facing enums. The decoded ones map from the raw wire strings via `fromWire`. An
// unrecognized wire value maps to `.unknown`, so a producer adding a value never breaks decoding. The wire's
// "nothing known" values (`NO_INFORMATION`, `NO_DATA_AVAILABLE`) map to nil, like an absent value.

/// A transit or street mode. Unrecognized values map to `.unknown`.
public enum TransitMode: String, Sendable, CaseIterable {
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
    case snowAndIce = "SNOW_AND_ICE"
    case subway = "SUBWAY"
    case taxi = "TAXI"
    case tram = "TRAM"
    case transit = "TRANSIT"
    case trolleybus = "TROLLEYBUS"
    case walk = "WALK"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> TransitMode? {
        guard let raw else { return nil }
        return TransitMode(rawValue: raw) ?? .unknown
    }
}

/// Whether a wheelchair user can board at a stop or ride a trip. Unrecognized values map to `.unknown`;
/// `NO_INFORMATION` maps to nil.
public enum WheelchairBoarding: String, Sendable, CaseIterable {
    case possible = "POSSIBLE"
    case notPossible = "NOT_POSSIBLE"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> WheelchairBoarding? {
        guard let raw, raw != "NO_INFORMATION" else { return nil }
        return WheelchairBoarding(rawValue: raw) ?? .unknown
    }
}

/// Whether bikes are allowed on a trip. Unrecognized values map to `.unknown`; `NO_INFORMATION` maps to nil.
public enum BikesAllowed: String, Sendable, CaseIterable {
    case allowed = "ALLOWED"
    case notAllowed = "NOT_ALLOWED"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> BikesAllowed? {
        guard let raw, raw != "NO_INFORMATION" else { return nil }
        return BikesAllowed(rawValue: raw) ?? .unknown
    }
}

/// GTFS-RT vehicle occupancy. Unrecognized values map to `.unknown`; `NO_DATA_AVAILABLE` maps to nil.
public enum OccupancyStatus: String, Sendable, CaseIterable {
    case empty = "EMPTY"
    case manySeatsAvailable = "MANY_SEATS_AVAILABLE"
    case fewSeatsAvailable = "FEW_SEATS_AVAILABLE"
    case standingRoomOnly = "STANDING_ROOM_ONLY"
    case crushedStandingRoomOnly = "CRUSHED_STANDING_ROOM_ONLY"
    case full = "FULL"
    case notAcceptingPassengers = "NOT_ACCEPTING_PASSENGERS"
    case notBoardable = "NOT_BOARDABLE"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> OccupancyStatus? {
        guard let raw, raw != "NO_DATA_AVAILABLE" else { return nil }
        return OccupancyStatus(rawValue: raw) ?? .unknown
    }
}

/// The realtime state of a departure/leg. Unrecognized values map to `.unknown`.
public enum RealtimeState: String, Sendable, CaseIterable {
    case added = "ADDED"
    case canceled = "CANCELED"
    case modified = "MODIFIED"
    case scheduled = "SCHEDULED"
    case updated = "UPDATED"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> RealtimeState? {
        guard let raw else { return nil }
        return RealtimeState(rawValue: raw) ?? .unknown
    }
}

/// Why routing failed. Unrecognized values map to `.unknown`.
public enum RoutingErrorCode: String, Sendable, CaseIterable {
    case locationNotFound = "LOCATION_NOT_FOUND"
    case noStopsInRange = "NO_STOPS_IN_RANGE"
    case noTransitConnection = "NO_TRANSIT_CONNECTION"
    case noTransitConnectionInSearchWindow = "NO_TRANSIT_CONNECTION_IN_SEARCH_WINDOW"
    case outsideBounds = "OUTSIDE_BOUNDS"
    case outsideServicePeriod = "OUTSIDE_SERVICE_PERIOD"
    case walkingBetterThanTransit = "WALKING_BETTER_THAN_TRANSIT"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> RoutingErrorCode {
        guard let raw else { return .unknown }
        return RoutingErrorCode(rawValue: raw) ?? .unknown
    }
}

/// Which input a routing error refers to. Unrecognized values map to `.unknown`.
public enum InputField: String, Sendable, CaseIterable {
    case dateTime = "DATE_TIME"
    case from = "FROM"
    case to = "TO"
    case via = "VIA"
    case unknown = "UNKNOWN"

    static func fromWire(_ raw: String?) -> InputField? {
        guard let raw else { return nil }
        return InputField(rawValue: raw) ?? .unknown
    }
}

/// How much delay a trip plan allows for: each leg's arrival is planned with the trip's typical delay at that stop,
/// the median at `.standard`, the 70th percentile at `.safe`, the 90th at `.verySafe`. Sent, never decoded.
public enum Reliability: String, Sendable, CaseIterable {
    case standard = "STANDARD"
    case safe = "SAFE"
    case verySafe = "VERY_SAFE"
}
