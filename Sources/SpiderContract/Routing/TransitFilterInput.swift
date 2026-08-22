public struct TransitFilterInput: Codable, Sendable {
    public let exclude: [TransitFilterSelectInput]?
    public let include: [TransitFilterSelectInput]?

    public init(
        exclude: [TransitFilterSelectInput]? = nil,
        include: [TransitFilterSelectInput]? = nil
    ) {
        self.exclude = exclude
        self.include = include
    }
}
