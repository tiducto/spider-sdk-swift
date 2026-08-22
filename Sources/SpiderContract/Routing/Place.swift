public struct Place: Codable, Sendable {
    public let name: String?
    public let stop: Stop?

    public init(
        name: String? = nil,
        stop: Stop? = nil
    ) {
        self.name = name
        self.stop = stop
    }
}
