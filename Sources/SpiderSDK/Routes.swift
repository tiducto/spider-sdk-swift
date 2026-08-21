import Foundation

/// A transit route (line) returned by the routes surface. Named `TransitRoute` to avoid colliding with the
/// routing `Route` (a page of itineraries). `mode` is the raw GTFS mode string, e.g. `BUS`, `TRAM`, `RAIL`.
public struct TransitRoute: Sendable, Equatable {
    public let routeId: String
    public let shortName: String?
    public let longName: String?
    public let mode: String
    public let routeType: Int
    public let agencyName: String?
    public let tripCount: Int
}

/// Search criteria for routes. `q` is a free-text query over shortName + longName; the other fields narrow it.
public struct RouteFilter: Sendable {
    public var q: String?
    public var mode: String?
    public var agency: String?
    public var limit: Int?

    public init(q: String? = nil, mode: String? = nil, agency: String? = nil, limit: Int? = nil) {
        self.q = q
        self.mode = mode
        self.agency = agency
        self.limit = limit
    }
}

/// The routes surface: full-text + attribute route search, and single-route lookup by id.
public final class SpiderRoutes {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// Searches routes by free text and/or transit mode and operating agency. Hits are busiest-first (by trip count).
    public func search(_ filter: RouteFilter) async throws -> SpiderResult<[TransitRoute]> {
        do {
            let response: RouteSearchResponse = try await transport.postJson(
                "/routes/search", buildRouteSearchRequest(filter), errorMessage: extractRouteError
            )
            return .success(response.hits.map(toRoute))
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            return .failure(toSpiderError(error))
        }
    }

    /// Looks up a single route by its feed-scoped id. Returns the route, or nil when no route matches; throws a
    /// `SpiderError` on a transport failure.
    public func byId(_ routeId: String) async throws -> TransitRoute? {
        do {
            let body = RouteSearchRequest(q: "", filter: "\"routeId\" = \"\(escapeRouteFilter(routeId))\"", sort: nil, limit: 1)
            let response: RouteSearchResponse = try await transport.postJson("/routes/search", body, errorMessage: extractRouteError)
            return response.hits.first.map(toRoute)
        } catch let error as SpiderContractMismatchError {
            throw error
        } catch {
            throw toSpiderError(error)
        }
    }
}

private func buildRouteSearchRequest(_ filter: RouteFilter) -> RouteSearchRequest {
    RouteSearchRequest(q: filter.q ?? "", filter: buildRouteFilterExpression(filter), sort: nil, limit: filter.limit)
}

private func buildRouteFilterExpression(_ filter: RouteFilter) -> String? {
    var clauses: [String] = []
    if let mode = filter.mode, !mode.isEmpty {
        clauses.append("\"mode\" = \"\(escapeRouteFilter(mode))\"")
    }
    if let agency = filter.agency, !agency.isEmpty {
        clauses.append("\"agencyName\" = \"\(escapeRouteFilter(agency))\"")
    }
    return clauses.isEmpty ? nil : clauses.joined(separator: " AND ")
}

private func escapeRouteFilter(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private func extractRouteError(_ text: String) -> String {
    if let data = text.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let message = obj["message"] as? String {
        return message
    }
    return String(text.prefix(300))
}

private func toRoute(_ hit: RouteHit) -> TransitRoute {
    TransitRoute(
        routeId: hit.routeId, shortName: hit.shortName, longName: hit.longName,
        mode: hit.mode, routeType: hit.routeType, agencyName: hit.agencyName, tripCount: hit.tripCount
    )
}

// MARK: - wire types (hand-written, mirroring the TS SDK; not generated)

private struct RouteSearchRequest: Encodable {
    let q: String
    let filter: String?
    let sort: [String]?
    let limit: Int?
}

private struct RouteSearchResponse: Decodable {
    let hits: [RouteHit]
    let query: String?
}

private struct RouteHit: Decodable {
    let routeId: String
    let shortName: String?
    let longName: String?
    let mode: String
    let routeType: Int
    let agencyName: String?
    let tripCount: Int
}
