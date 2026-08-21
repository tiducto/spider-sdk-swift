import Foundation
import SpiderSDK

// Documentation examples for the Spider Swift SDK routes surface. Each function holds one named region the
// docs site inlines verbatim. The functions type-check against the real SDK; they are never invoked.

/// Search routes (lines) by free text, transit mode, and operating agency.
func routesSearch(client: SpiderClient) async throws {
    // [START routesSearch]
    let result = try await client.routes.search(RouteFilter(
        q: "express",
        mode: "BUS",
        agency: "DPMB",
        limit: 20
    ))

    // Hits come back busiest-first (by trip count).
    if case .success(let routes) = result {
        for route in routes {
            print("\(route.shortName ?? "?") \(route.longName ?? "") — \(route.mode), \(route.tripCount) trips")
        }
    }
    // [END routesSearch]
}

/// Look up a single route by its id: found, not-found (nil), or a transport error.
func routesById(client: SpiderClient) async throws {
    // [START routesById]
    do {
        if let route = try await client.routes.byId("1:L4") {
            print("found \(route.shortName ?? "?") operated by \(route.agencyName ?? "?")")
        } else {
            print("no route with that id")
        }
    } catch let error as SpiderError {
        print("lookup failed: \(error.message)")
    }
    // [END routesById]
}
