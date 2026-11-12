/// Whether and how a rider boards (`pickupType`) or alights (`dropoffType`) at a stop, from the GTFS `pickup_type` / `drop_off_type`: `SCHEDULED` regularly (0, or the field left empty), `NONE` not at all (1), `CALL_AGENCY` only after phoning the agency (2), `COORDINATE_WITH_DRIVER` only by arranging it with the driver, a stop on request (3).
public enum PickupDropoffType: String, Codable, Sendable, CaseIterable {
    case callAgency = "CALL_AGENCY"
    case coordinateWithDriver = "COORDINATE_WITH_DRIVER"
    case `none` = "NONE"
    case scheduled = "SCHEDULED"
    case unknown = "UNKNOWN"

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PickupDropoffType(rawValue: raw) ?? .unknown
    }
}
