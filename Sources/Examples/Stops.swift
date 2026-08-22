import Foundation
import SpiderSDK

/// Search stops by free-text name.
func search(client: SpiderClient) async throws {
    // [START search]
    let result = try await client.stops.search(StopFilter(name: "Hlavní nádraží"))
    if case .success(let stops) = result {
        for stop in stops {
            print("\(stop.name) (\(stop.gtfsId)) — \(stop.city ?? "?")")
        }
    }
    // [END search]
}

/// Take the first search hit and feed its id straight into departures.
func reuseHit(client: SpiderClient) async throws {
    // [START reuseHit]
    let hits = try await client.stops.search(StopFilter(name: "Náměstí")).get()
    guard let hit = hits.first else { return }

    let departures = try await client.routing.departures(hit.gtfsId, numberOfDepartures: 5)

    if let lat = hit.lat, let lon = hit.lon {
        let nearby = Location.coordinate(lat, lon)
        print("planning from \(hit.name) at \(nearby)")
    }
    // [END reuseHit]
    _ = departures
}

/// Find the stops nearest to a coordinate, closest first, within a radius.
func stopsNearby(client: SpiderClient) async throws {
    // [START stopsNearby]
    let result = try await client.stops.near(49.1951, 16.6068, radiusMeters: 500)
    if case .success(let stops) = result {
        for stop in stops {
            print("\(stop.name) at \(stop.lat ?? 0),\(stop.lon ?? 0)")
        }
    }
    // [END stopsNearby]
}

/// Look up a single stop by its GTFS id: found, not-found (nil), or a transport error.
func stopById(client: SpiderClient) async throws {
    // [START stopById]
    do {
        if let stop = try await client.stops.byId("U123Z1") {
            print("found \(stop.name) in \(stop.city ?? "?")")
        } else {
            print("no stop with that id")
        }
    } catch let error as SpiderError {
        print("lookup failed: \(error.message)")
    }
    // [END stopById]
}

/// Search stops constrained to a city (an administrative-area filter).
func stopsByCity(client: SpiderClient) async throws {
    // [START stopsByCity]
    let result = try await client.stops.search(StopFilter(name: "náměstí", city: "Brno"))
    if case .success(let stops) = result {
        for stop in stops {
            print("\(stop.name) — \(stop.city ?? "?")")
        }
    }
    // [END stopsByCity]
}
