public struct TransitPreferencesInput: Codable, Sendable {
    public let alight: AlightPreferencesInput?
    public let board: BoardPreferencesInput?
    public let filters: [TransitFilterInput]?
    public let timetable: TimetablePreferencesInput?
    public let transfer: TransferPreferencesInput?

    public init(
        alight: AlightPreferencesInput? = nil,
        board: BoardPreferencesInput? = nil,
        filters: [TransitFilterInput]? = nil,
        timetable: TimetablePreferencesInput? = nil,
        transfer: TransferPreferencesInput? = nil
    ) {
        self.alight = alight
        self.board = board
        self.filters = filters
        self.timetable = timetable
        self.transfer = transfer
    }
}
