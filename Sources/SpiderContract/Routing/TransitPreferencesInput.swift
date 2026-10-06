/// Transit preferences.
public struct TransitPreferencesInput: Codable, Sendable {
    public let transfer: TransferPreferencesInput?
    public let board: BoardPreferencesInput?
    public let alight: AlightPreferencesInput?
    /// Routes or agencies to leave out of the search.
    public let filters: [TransitFilterInput]?

    public init(
        transfer: TransferPreferencesInput? = nil,
        board: BoardPreferencesInput? = nil,
        alight: AlightPreferencesInput? = nil,
        filters: [TransitFilterInput]? = nil
    ) {
        self.transfer = transfer
        self.board = board
        self.alight = alight
        self.filters = filters
    }
}
