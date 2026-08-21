import Foundation
import SpiderSDK

/// Construct a client to reach the routing surface.
func routingSetup() -> SpiderClient {
    // [START setup]
    let client = SpiderClient(
        baseURL: "https://your-env-slug.api.tiducto.eu",
        apiKey: "your-api-key"
    )
    // [END setup]
    return client
}

/// Plan a trip and walk the itineraries and their legs.
func planTrip(client: SpiderClient) async throws {
    // [START planTrip]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        first: 3
    ))

    switch result {
    case .success(let route):
        for edge in route.edges {
            let itinerary = edge.itinerary
            print("\(itinerary.start ?? "?") → \(itinerary.end ?? "?"), \(itinerary.numberOfTransfers) transfers")
            for leg in itinerary.legs {
                let mode = leg.mode?.rawValue ?? "WALK"
                let route = leg.routeShortName ?? "walk"
                print("  \(mode) \(route): \(leg.fromName ?? "?") → \(leg.toName ?? "?") (\(Int(leg.durationSeconds ?? 0))s)")
            }
        }
    case .failure(let error):
        print("plan failed: \(error.message)")
    }
    // [END planTrip]
}

/// Plan for a specific departure time instead of "now".
func planForTime(client: SpiderClient) async throws {
    // [START planForTime]
    let inOneHour = Date().addingTimeInterval(60 * 60)
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        first: 3,
        departAt: inOneHour
    ))
    // [END planForTime]
    _ = result
}

/// List the next departures from a stop.
func departures(client: SpiderClient) async throws {
    // [START departures]
    let result = try await client.routing.departures("U123Z1", numberOfDepartures: 5)
    if case .success(let departures) = result {
        for departure in departures {
            let when = Date(timeIntervalSince1970: Double(departure.scheduledTimeEpochMs) / 1000)
            print("\(departure.routeShortName ?? "?") → \(departure.headsign ?? "?") at \(when)")
        }
    }
    // [END departures]
}

/// Page forward: fetch the next page of itineraries after the first result.
func laterItineraries(client: SpiderClient) async throws {
    // [START laterItineraries]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        first: 3
    ))

    switch result {
    case .success(let firstPage):
        // planNext returns nil when there is no further page.
        guard let next = try await client.routing.planNext(firstPage) else {
            print("No later itineraries — that was the last page")
            return
        }
        switch next {
        case .success(let laterPage):
            for edge in laterPage.edges {
                print("\(edge.itinerary.start ?? "?") → \(edge.itinerary.end ?? "?")")
            }
        case .failure(let error):
            print("next page failed: \(error.message)")
        }
    case .failure(let error):
        print("plan failed: \(error.message)")
    }
    // [END laterItineraries]
}

/// Look up a single trip's timetable.
func tripLookup(client: SpiderClient) async throws {
    // [START tripLookup]
    let result = try await client.routing.trip("1:12345")
    if case .success(let trip) = result {
        for stop in trip.stops {
            let arrival = stop.scheduledArrivalEpochMs ?? 0
            let departure = stop.scheduledDepartureEpochMs ?? 0
            print("\(stop.name): arr \(arrival) / dep \(departure)")
        }
    }
    // [END tripLookup]
}
