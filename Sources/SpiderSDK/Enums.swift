import Foundation

// The public, consumer-facing enums. They map from the raw wire strings via `fromWire`. Two kinds:
//  - OPEN (TransitMode, OccupancyStatus, RealtimeState, RoutingErrorCode, InputField): an unrecognized wire
//    value maps to `.unknown` so a producer adding a value never breaks decoding.
//  - CLOSED (WheelchairBoarding, BikesAllowed): only the known values map; anything else maps to nil.

/// A transit or street mode. Open: unrecognized values map to `.unknown`.
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

/// Whether a stop is wheelchair accessible. Closed: unknown wire values map to nil.
public enum WheelchairBoarding: String, Sendable, CaseIterable {
    case possible = "POSSIBLE"
    case notPossible = "NOT_POSSIBLE"

    static func fromWire(_ raw: String?) -> WheelchairBoarding? {
        switch raw {
        case "POSSIBLE": return .possible
        case "NOT_POSSIBLE": return .notPossible
        default: return nil
        }
    }
}

/// Whether bikes are allowed on a trip. Closed: unknown wire values map to nil.
public enum BikesAllowed: String, Sendable, CaseIterable {
    case allowed = "ALLOWED"
    case notAllowed = "NOT_ALLOWED"

    static func fromWire(_ raw: String?) -> BikesAllowed? {
        switch raw {
        case "ALLOWED": return .allowed
        case "NOT_ALLOWED": return .notAllowed
        default: return nil
        }
    }
}

/// GTFS-RT vehicle occupancy. Open: unrecognized values map to `.unknown`; `NO_DATA_AVAILABLE` maps to nil.
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

/// The realtime state of a departure/leg. Open: unrecognized values map to `.unknown`.
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

/// Why routing failed. Open: unrecognized values map to `.unknown`.
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

/// Which input a routing error refers to. Open: unrecognized values map to `.unknown`.
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
