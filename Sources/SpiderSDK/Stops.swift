import Foundation

/// A stop returned by search.
public struct Stop: Sendable, Equatable {
    public let gtfsId: String
    public let name: String
    public let lat: Double?
    public let lon: Double?
    public let country: String?
    public let region: String?
    public let district: String?
    public let city: String?
    public let suburb: String?
}

/// Search criteria. `name` is a free-text query; the admin fields narrow it by administrative area.
public struct StopFilter: Sendable {
    public var name: String?
    public var country: String?
    public var region: String?
    public var district: String?
    public var city: String?
    public var suburb: String?

    public init(
        name: String? = nil,
        country: String? = nil,
        region: String? = nil,
        district: String? = nil,
        city: String? = nil,
        suburb: String? = nil
    ) {
        self.name = name
        self.country = country
        self.region = region
        self.district = district
        self.city = city
        self.suburb = suburb
    }
}

/// The stops surface: text + administrative-area stop search.
public final class SpiderStops {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Searches stops by free text and/or administrative area.
    public func search(_ filter: StopFilter) async throws -> SpiderResult<[Stop]> {
        do {
            let body = StopSearchRequest(q: filter.name ?? "", filter: buildFilterExpression(filter))
            let response: StopSearchResponse = try await transport.postJson("/stops/search", body, errorMessage: extractStopError)
            return .success(response.hits.map(toStop))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }
}

// The admin keys, in the fixed order they compose into the filter expression.
private func buildFilterExpression(_ filter: StopFilter) -> String? {
    let pairs: [(String, String?)] = [
        ("country", filter.country),
        ("region", filter.region),
        ("district", filter.district),
        ("city", filter.city),
        ("suburb", filter.suburb),
    ]
    var clauses: [String] = []
    for (key, value) in pairs {
        guard let value, !value.isEmpty else { continue }
        clauses.append("\"\(escapeFilter(key))\" = \"\(escapeFilter(value))\"")
    }
    return clauses.isEmpty ? nil : clauses.joined(separator: " AND ")
}

// Escape backslashes then double-quotes (order matters) for a Meilisearch filter literal.
private func escapeFilter(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private func extractStopError(_ text: String) -> String {
    if let data = text.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let message = obj["message"] as? String {
        return message
    }
    return String(text.prefix(300))
}

private func toStop(_ hit: StopHit) -> Stop {
    Stop(
        gtfsId: hit.gtfsId, name: hit.name, lat: hit.lat, lon: hit.lon,
        country: hit.country, region: hit.region, district: hit.district, city: hit.city, suburb: hit.suburb
    )
}

// MARK: - wire types (hand-written, mirroring the TS SDK; not generated)

private struct StopSearchRequest: Encodable {
    let q: String
    let filter: String?
}

private struct StopSearchResponse: Decodable {
    let hits: [StopHit]
    let query: String?
}

private struct StopHit: Decodable {
    let gtfsId: String
    let name: String
    let lat: Double?
    let lon: Double?
    let country: String?
    let region: String?
    let district: String?
    let city: String?
    let suburb: String?
}
