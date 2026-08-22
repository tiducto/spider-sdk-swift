import Foundation

/// An origin, destination, or via point: either a coordinate or a stop id.
public enum Location: Sendable, Equatable {
    case coordinate(latitude: Double, longitude: Double)
    case stop(id: String)

    /// A geographic coordinate.
    public static func coordinate(_ latitude: Double, _ longitude: Double) -> Location {
        .coordinate(latitude: latitude, longitude: longitude)
    }

    /// A stop by its GTFS id.
    public static func stop(_ id: String) -> Location {
        .stop(id: id)
    }
}

/// A via constraint on a trip plan: pass through a set of stops, or visit a place with a minimum dwell.
public enum ViaLocation: Sendable, Equatable {
    case passThrough(stopIds: [String])
    case visit(location: Location, minimumWaitSeconds: Int)

    /// Require the route to pass through any of the given stops (no dwell).
    public static func passThrough(_ stopIds: String...) -> ViaLocation {
        .passThrough(stopIds: stopIds)
    }

    /// Require the route to visit a place, optionally dwelling at least `minimumWaitSeconds` there.
    public static func visit(_ location: Location, minimumWaitSeconds: Int = 0) -> ViaLocation {
        .visit(location: location, minimumWaitSeconds: minimumWaitSeconds)
    }
}
