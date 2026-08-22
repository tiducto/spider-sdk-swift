public struct ParkingFilter: Codable, Sendable {
    public let not: [ParkingFilterOperation]?
    public let select: [ParkingFilterOperation]?

    public init(
        not: [ParkingFilterOperation]? = nil,
        select: [ParkingFilterOperation]? = nil
    ) {
        self.not = not
        self.select = select
    }
}
