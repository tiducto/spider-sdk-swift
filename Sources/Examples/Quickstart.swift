import Foundation
import SpiderSDK

// Documentation examples for the Spider Swift SDK quickstart. Each function holds one named region that the
// docs site inlines verbatim. The functions type-check against the real SDK; they are never invoked.

/// Construct a client and make your first trip-plan call.
func firstCall() async throws {
    // [START firstCall]
    let client = SpiderClient(
        baseURL: "https://your-env-slug.api.tiducto.eu",
        apiKey: "your-api-key"
    )

    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1908, 16.6128),
        destination: .coordinate(49.2270, 16.5273),
        departAt: Date(),
        searchWindowMinutes: 60
    ))
    // [END firstCall]
    _ = result
}

/// Every call returns a `SpiderResult` you branch on before reading the value.
func handleResult(client: SpiderClient) async throws {
    // [START handleResult]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1908, 16.6128),
        destination: .coordinate(49.2270, 16.5273),
        departAt: Date(),
        searchWindowMinutes: 60
    ))

    switch result {
    case .success(let route):
        for edge in route.edges {
            let itinerary = edge.itinerary
            let legs = itinerary.legs.map { $0.mode?.rawValue ?? "WALK" }.joined(separator: " → ")
            print("\(itinerary.durationSeconds / 60) min, \(itinerary.numberOfTransfers) transfers: \(legs)")
        }
    case .failure(let error):
        print("plan failed: \(error.code.rawValue) — \(error.message)")
    }
    // [END handleResult]
}

/// The same client reaches the stops and realtime surfaces too.
func otherSurfaces(client: SpiderClient, tripId: String) async throws {
    // [START otherSurfaces]
    let stops = try await client.stops.search(StopFilter(name: "central"))
    if case .success(let hits) = stops {
        print("found \(hits.count) matching stops")
    }

    let vehicle = try await client.realtime.vehicleForTrip(tripId)
    if case .success(let update) = vehicle, let live = update.vehicle {
        print("vehicle at \(live.latitude ?? 0),\(live.longitude ?? 0)")
    }
    // [END otherSurfaces]
}
