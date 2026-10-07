/// A filter on the trips the search may ride.
public struct TransitFilterInput: Codable, Sendable {
    /// Leave out every trip of a route or agency that any of these selectors names. An id that names no route or agency of the environment's feed, a bare or foreign-prefixed one included, excludes nothing.
    public let exclude: [TransitFilterSelectInput]?

    public init(
        exclude: [TransitFilterSelectInput]? = nil
    ) {
        self.exclude = exclude
    }
}
