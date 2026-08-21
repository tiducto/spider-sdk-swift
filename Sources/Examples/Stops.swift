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
