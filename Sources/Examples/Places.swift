import Foundation
import SpiderSDK

/// Search places — stops, addresses, municipalities and points of interest — near the rider.
func searchPlaces(client: SpiderClient) async throws {
    // [START searchPlaces]
    let result = try await client.places.search("Údolní 53", near: GeoPoint(lat: 49.1951, lng: 16.6068))
    if case .success(let hits) = result {
        for hit in hits {
            switch hit.type {
            case .stop:
                // A stop's id is the one routing takes.
                print("stop \(hit.name) (\(hit.id))")
            case .address, .place, .poi:
                let distance = hit.distance.map { " — \($0) m" } ?? ""
                print("\(hit.name), \(hit.city ?? "?")\(distance)")
            case .unknown:
                continue // a kind this app doesn't handle yet
            }
        }
    }
    // [END searchPlaces]
}
