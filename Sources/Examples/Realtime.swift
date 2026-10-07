import Foundation
import SpiderSDK

/// Construct a client to reach the realtime surface.
func realtimeSetup() -> SpiderClient {
    // [START setup]
    let client = SpiderClient(
        baseURL: "https://your-env-slug.api.tiducto.eu",
        apiKey: "your-api-key"
    )
    // [END setup]
    return client
}

/// Opt in to automatic retries on the realtime surface.
func setupWithRetry() -> SpiderClient {
    // [START setupWithRetry]
    let client = SpiderClient(
        baseURL: "https://your-env-slug.api.tiducto.eu",
        apiKey: "your-api-key",
        options: SpiderClientOptions(
            realtime: FeatureOptions(autoRetry: AutoRetryOptions(maxAttempts: 3))
        )
    )
    // [END setupWithRetry]
    return client
}

/// A hand-rolled poll loop: fetch delays roughly every 15 seconds until the task is cancelled.
func poll(client: SpiderClient) async throws {
    // [START poll]
    // One GTFS service date per call — take it from each plan leg's `serviceDate`; ids are feed-prefixed.
    let tripIds = ["1:T-1", "1:T-2"]
    let serviceDate = "2026-01-01"
    while !Task.isCancelled {
        switch try await client.realtime.delays(serviceDate: serviceDate, tripIds: tripIds) {
        case .success(let delays):
            updateBoard(delays)
        case .failure(let error):
            log("delays failed: \(error.message)")
        }
        try await Task.sleep(nanoseconds: 15_000_000_000)
    }
    // [END poll]
}

/// A change-detecting stream of vehicle positions via the SDK's built-in polling helper (yields only when the data changes).
func pollHelper(client: SpiderClient) async throws {
    // [START pollHelper]
    for try await update in client.realtime.pollVehicles(["1:T-1", "1:T-2"], intervalMs: 15_000) {
        if case .success(let positions) = update {
            for vehicle in positions.vehicles {
                placeMarker(lat: vehicle.latitude, lon: vehicle.longitude)
            }
        }
    }
    // [END pollHelper]
}

/// Fetch live vehicle positions for a set of trips.
func vehicles(client: SpiderClient) async throws {
    // [START vehicles]
    let result = try await client.realtime.vehicles(["1:T-1", "1:T-2"])
    if case .success(let positions) = result {
        for vehicle in positions.vehicles {
            print("\(vehicle.tripId) at \(vehicle.latitude),\(vehicle.longitude)")
        }
    }
    // [END vehicles]
}

/// The live vehicle for one trip — a 404 is a normal "none currently reporting", not an error.
func vehicleForTrip(client: SpiderClient, tripId: String) async throws {
    // [START vehicleForTrip]
    let result = try await client.realtime.vehicleForTrip(tripId)
    if case .success(let update) = result {
        if let vehicle = update.vehicle {
            placeMarker(lat: vehicle.latitude, lon: vehicle.longitude)
        } else {
            log("no vehicle currently reporting for \(tripId)")
        }
    }
    // [END vehicleForTrip]
}

/// Live schedule deviation for a set of trips, printed in minutes.
func delays(client: SpiderClient) async throws {
    // [START delays]
    // Delays are per trip instance — pass the GTFS service date (`YYYY-MM-DD`) the trips run on.
    let result = try await client.realtime.delays(serviceDate: "2026-01-01", tripIds: ["1:T-1", "1:T-2"])
    if case .success(let trips) = result {
        for delay in trips.delays {
            guard let seconds = delay.delaySeconds else { continue }
            let minutes = seconds / 60
            let sign = minutes >= 0 ? "+" : ""
            print("\(delay.tripId): \(sign)\(minutes) min")
        }
    }
    // [END delays]
}

/// All active service alerts for the environment.
func alerts(client: SpiderClient) async throws {
    // [START alerts]
    let result = try await client.realtime.alerts()
    if case .success(let active) = result {
        for alert in active.alerts {
            print("\(alert.headerText ?? ""): \(alert.descriptionText ?? "")")
        }
    }
    // [END alerts]
}

// MARK: - Illustrative helper stubs (kept private so the example bodies read cleanly).

private func updateBoard(_ delays: TripDelays) { _ = delays }
private func log(_ message: String) { print(message) }
private func placeMarker(lat: Double, lon: Double) { _ = (lat, lon) }
