/// Transit preferences.
public struct TransitPreferencesInput: Codable, Sendable {
    public let transfer: AnyCodable?
    public let board: AnyCodable?
    public let alight: AnyCodable?
    /// Routes or agencies to leave out of the search.
    public let filters: [TransitFilterInput]?

    public init(
        transfer: AnyCodable? = nil,
        board: AnyCodable? = nil,
        alight: AnyCodable? = nil,
        filters: [TransitFilterInput]? = nil
    ) {
        self.transfer = transfer
        self.board = board
        self.alight = alight
        self.filters = filters
    }
}
