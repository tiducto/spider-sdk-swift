import Foundation

/// The vehicle running a trip run, with its features: the same value on `Leg.vehicle`, `Departure.vehicle`,
/// `TripDetails.vehicle` and `TripUpdate.vehicle`. Every field is nil when the feed doesn't say.
public struct TripVehicle: Sendable, Equatable {
    /// The vehicle's id, feed-prefixed (`<feedId>:<id>`) as `LiveVehicle.vehicleId`, so it names the same vehicle.
    public let id: String?
    /// The vehicle's user-visible label, as the feed gives it.
    public let label: String?
    /// Whether a wheelchair user can ride this vehicle: `.possible` or `.notPossible`, `.unknown` for a value added
    /// later. Nil when the feed doesn't say. It is the vehicle's realtime access, separate from the timetable's
    /// `Departure.wheelchairAccessible` and `TripDetails.wheelchairAccessible`.
    public let wheelchairAccessible: WheelchairBoarding?
    /// Whether the vehicle is air-conditioned.
    public let airConditioning: Bool?
    /// Whether the vehicle offers Wi-Fi.
    public let wifi: Bool?
    /// Whether the vehicle accepts card payment on board.
    public let cardPayment: Bool?
}
