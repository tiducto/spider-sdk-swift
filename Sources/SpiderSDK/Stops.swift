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

/// A WGS84 point. `lng` mirrors the transit-industry `lon`, but the input side reads as lat/lng.
public struct GeoPoint: Sendable, Equatable {
    public let lat: Double
    public let lng: Double
    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

/// A WGS84 bounding box: south-west corner (`min*`) to north-east corner (`max*`).
public struct GeoBoundingBox: Sendable, Equatable {
    public let minLat: Double
    public let minLng: Double
    public let maxLat: Double
    public let maxLng: Double
    public init(minLat: Double, minLng: Double, maxLat: Double, maxLng: Double) {
        self.minLat = minLat
        self.minLng = minLng
        self.maxLat = maxLat
        self.maxLng = maxLng
    }
}

/// Search criteria. `name` is a free-text query; the admin fields narrow it by administrative area, and the
/// geo fields narrow it by location. `radiusMeters` and `sortByDistance` both require `near`.
public struct StopFilter: Sendable {
    public var name: String?
    public var country: String?
    public var region: String?
    public var district: String?
    public var city: String?
    public var suburb: String?
    /// Geographic anchor for `radiusMeters` and `sortByDistance`.
    public var near: GeoPoint?
    /// Restrict to stops within this many metres of `near`. Requires `near`.
    public var radiusMeters: Double?
    /// Restrict to stops inside this box. Independent of `near`.
    public var bbox: GeoBoundingBox?
    /// Sort results by distance from `near`, nearest first. Requires `near`.
    public var sortByDistance: Bool
    /// Cap the number of hits returned.
    public var limit: Int?

    public init(
        name: String? = nil,
        country: String? = nil,
        region: String? = nil,
        district: String? = nil,
        city: String? = nil,
        suburb: String? = nil,
        near: GeoPoint? = nil,
        radiusMeters: Double? = nil,
        bbox: GeoBoundingBox? = nil,
        sortByDistance: Bool = false,
        limit: Int? = nil
    ) {
        self.name = name
        self.country = country
        self.region = region
        self.district = district
        self.city = city
        self.suburb = suburb
        self.near = near
        self.radiusMeters = radiusMeters
        self.bbox = bbox
        self.sortByDistance = sortByDistance
        self.limit = limit
    }
}

/// The stops surface: text + administrative-area stop search.
public final class SpiderStops {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Searches stops by free text, administrative area, and/or geography.
    public func search(_ filter: StopFilter) async throws -> SpiderResult<[Stop]> {
        do {
            let body = try buildStopSearchRequest(filter)
            let response: StopSearchResponse = try await transport.postJson("/stops/search", body, errorMessage: extractStopError)
            return .success(response.hits.map(toStop))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Looks up a single stop by its GTFS id. Returns the stop, or nil when no stop matches; throws a
    /// `SpiderError` on a transport failure.
    public func byId(_ gtfsId: String) async throws -> Stop? {
        do {
            let body = StopSearchRequest(q: "", filter: "\"gtfsId\" = \"\(escapeFilter(gtfsId))\"", sort: nil, limit: 1)
            let response: StopSearchResponse = try await transport.postJson("/stops/search", body, errorMessage: extractStopError)
            return response.hits.first.map(toStop)
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            throw toSpiderError(error)
        }
    }

    /// Stops around a point, nearest first. Pass `radiusMeters` to bound the search.
    public func near(_ lat: Double, _ lng: Double, radiusMeters: Double? = nil, limit: Int? = nil) async throws -> SpiderResult<[Stop]> {
        try await search(StopFilter(near: GeoPoint(lat: lat, lng: lng), radiusMeters: radiusMeters, sortByDistance: true, limit: limit))
    }

    /// Stops inside a bounding box.
    public func within(_ bbox: GeoBoundingBox, limit: Int? = nil) async throws -> SpiderResult<[Stop]> {
        try await search(StopFilter(bbox: bbox, limit: limit))
    }
}

// Builds the wire request, validating that the geo options that need an anchor have one, and adding the
// distance sort when requested.
private func buildStopSearchRequest(_ filter: StopFilter) throws -> StopSearchRequest {
    if filter.radiusMeters != nil && filter.near == nil {
        throw SpiderError(code: .unknown, message: "stops.search: `radiusMeters` requires `near`")
    }
    if filter.sortByDistance && filter.near == nil {
        throw SpiderError(code: .unknown, message: "stops.search: `sortByDistance` requires `near`")
    }
    var sort: [String]?
    if filter.sortByDistance, let near = filter.near {
        sort = ["_geoPoint(\(near.lat), \(near.lng)):asc"]
    }
    return StopSearchRequest(q: filter.name ?? "", filter: buildFilterExpression(filter), sort: sort, limit: filter.limit)
}

// The admin keys, in the fixed order they compose into the filter expression, followed by the geo clauses.
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
    if let radius = filter.radiusMeters, let near = filter.near {
        clauses.append("_geoRadius(\(near.lat), \(near.lng), \(radius))")
    }
    if let bbox = filter.bbox {
        clauses.append("_geoBoundingBox([\(bbox.maxLat), \(bbox.maxLng)], [\(bbox.minLat), \(bbox.minLng)])")
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
    let sort: [String]?
    let limit: Int?
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
