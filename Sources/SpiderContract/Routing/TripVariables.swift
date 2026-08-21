public struct TripVariables: Codable, Sendable {
    public let id: String
    public let serviceDate: String?

    public init(
        id: String,
        serviceDate: String? = nil
    ) {
        self.id = id
        self.serviceDate = serviceDate
    }
}
