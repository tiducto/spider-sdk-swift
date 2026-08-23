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
    // The recommended shape: a departure time plus a search window, not "N results from now".
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        departAt: Date(),
        searchWindowMinutes: 60
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
        departAt: inOneHour,
        searchWindowMinutes: 30
    ))
    // [END planForTime]
    _ = result
}

/// List the next departures from a stop, reading both the scheduled and the live realtime fields.
func departures(client: SpiderClient) async throws {
    // [START departures]
    let result = try await client.routing.departures("U123Z1", numberOfDepartures: 5)
    if case .success(let departures) = result {
        for departure in departures {
            // The scheduled time is always present; the realtime time is filled in once the trip is tracked.
            let scheduled = Date(timeIntervalSince1970: Double(departure.scheduledTimeEpochMs) / 1000)
            let route = departure.routeShortName ?? departure.routeLongName ?? "?"
            let mode = departure.mode?.rawValue ?? "?"
            print("\(mode) \(route) → \(departure.headsign ?? "?") at \(scheduled)")

            if departure.isRealtime, let liveMs = departure.realtimeTimeEpochMs {
                let live = Date(timeIntervalSince1970: Double(liveMs) / 1000)
                let state = departure.realtimeState?.rawValue ?? "UPDATED"
                print("  live \(state): now \(live) (trip \(departure.tripGtfsId ?? "?"))")
            }
        }
    }
    // [END departures]
}

/// Page forward: fetch the next page of itineraries after the first result.
func laterItineraries(client: SpiderClient) async throws {
    // [START laterItineraries]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747)
    ))

    switch result {
    case .success(let firstPage):
        // planNext returns nil when there is no further page.
        guard let next = try await client.routing.planNext(firstPage) else {
            print("No later itineraries — that was the last window")
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

/// Restrict the search to specific transit modes (here tram + subway only).
func planWithModes(client: SpiderClient) async throws {
    // [START planWithModes]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        allowedTransitModes: [.tram, .subway]
    ))

    if case .success(let route) = result {
        for edge in route.edges {
            let modes = edge.itinerary.legs.compactMap { $0.mode?.rawValue }.joined(separator: " → ")
            print("\(edge.itinerary.durationSeconds / 60) min via \(modes)")
        }
    }
    // [END planWithModes]
}

/// Plan to arrive by a deadline instead of departing now.
func arriveBy(client: SpiderClient) async throws {
    // [START arriveBy]
    let deadline = Date().addingTimeInterval(2 * 60 * 60) // arrive within two hours
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        arriveBy: deadline,
        searchWindowMinutes: 60
    ))

    switch result {
    case .success(let route):
        for edge in route.edges {
            print("depart \(edge.itinerary.start ?? "?") → arrive \(edge.itinerary.end ?? "?")")
        }
    case .failure(let error):
        print("plan failed: \(error.message)")
    }
    // [END arriveBy]
}

/// Page backward: fetch the itineraries earlier than the first result.
func earlierItineraries(client: SpiderClient) async throws {
    // [START earlierItineraries]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747)
    ))

    switch result {
    case .success(let firstPage):
        // planPrevious returns nil when there is no earlier page.
        guard let previous = try await client.routing.planPrevious(firstPage) else {
            print("No earlier itineraries — that was the first window")
            return
        }
        switch previous {
        case .success(let earlierPage):
            for edge in earlierPage.edges {
                print("\(edge.itinerary.start ?? "?") → \(edge.itinerary.end ?? "?")")
            }
        case .failure(let error):
            print("previous page failed: \(error.message)")
        }
    case .failure(let error):
        print("plan failed: \(error.message)")
    }
    // [END earlierItineraries]
}

/// Require the trip to pass through a via point, dwelling at least five minutes there.
func planVia(client: SpiderClient) async throws {
    // [START planVia]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        via: [.visit(.coordinate(49.2002, 16.6110), minimumWaitSeconds: 300)]
    ))

    if case .success(let route) = result {
        for edge in route.edges {
            print("\(edge.itinerary.numberOfTransfers) transfers, \(edge.itinerary.durationSeconds / 60) min via the waypoint")
        }
    }
    // [END planVia]
}

/// Plan a wheelchair-accessible trip and read the accessibility info off the result.
func wheelchairPlan(client: SpiderClient) async throws {
    // [START wheelchairPlan]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        wheelchairAccessible: true
    ))

    if case .success(let route) = result {
        for edge in route.edges {
            let itinerary = edge.itinerary
            let score = itinerary.accessibilityScore.map { String(format: "%.2f", $0) } ?? "n/a"
            print("accessibility score \(score):")
            for leg in itinerary.legs {
                let boarding = leg.fromWheelchair == .possible ? "accessible" : "check locally"
                print("  \(leg.mode?.rawValue ?? "WALK") from \(leg.fromName ?? "?") (\(boarding))")
            }
        }
    }
    // [END wheelchairPlan]
}

/// Set several optional request options at once — including the transfer cap and the search window.
func planWithOptions(client: SpiderClient) async throws {
    // [START planWithOptions]
    let result = try await client.routing.plan(PlanOptions(
        origin: .coordinate(49.1951, 16.6068),
        destination: .coordinate(49.2246, 16.5747),
        departAt: Date().addingTimeInterval(30 * 60), // leave in half an hour
        allowedTransitModes: [.tram, .bus, .subway],  // empty (the default) means every mode
        maxTransfers: 1,                               // at most one transfer
        searchWindowMinutes: 90                        // widen the window from the 60-minute default
    ))

    if case .success(let route) = result {
        for edge in route.edges {
            print("\(edge.itinerary.durationSeconds / 60) min, \(edge.itinerary.numberOfTransfers) transfers")
        }
    }
    // [END planWithOptions]
}

/// Branch on the stable `SpiderError.code` taxonomy for programmatic error handling.
func handleRoutingErrors(client: SpiderClient) async throws {
    // [START handleErrors]
    do {
        let result = try await client.routing.plan(PlanOptions(
            origin: .coordinate(49.1951, 16.6068),
            destination: .coordinate(49.2246, 16.5747),
            departAt: Date(),
            searchWindowMinutes: 60
        ))

        switch result {
        case .success(let route):
            print("\(route.edges.count) itineraries")
        case .failure(let error):
            // `error.code` is the stable, language-agnostic category — branch on it, not on `message`.
            switch error.code {
            case .unauthorized:
                print("check your API key (HTTP \(error.httpStatus ?? 0))")
            case .badRequest:
                // A server validation failure: over-cap searchWindow, bad via, or a missing required field.
                print("invalid request on \(error.field ?? "input"): \(error.message)")
            case .rateLimited:
                print("slow down — too many requests")
            case .timeout:
                print("the gateway took too long; retry")
            case .network:
                print("no connection to the gateway")
            case .notFound:
                print("nothing matched this request")
            case .server:
                print("gateway error \(error.httpStatus ?? 0), code=\(error.serverCode ?? "?")")
            case .decoding:
                print("could not decode the response")
            case .unknown:
                print("unexpected failure: \(error.message)")
            }
        }
    } catch let mismatch as SpiderContractMismatchError {
        // The one failure the SDK throws instead of returning: the gateway speaks a different MAJOR contract version.
        print("SDK/gateway contract mismatch: \(mismatch.message)")
    }
    // [END handleErrors]
}
