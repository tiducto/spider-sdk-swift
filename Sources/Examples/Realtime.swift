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
    // Group trip ids by the GTFS service date they run on — take it from each plan leg's `serviceDate`.
    let tripIds = ["T-1", "T-2"]
    let serviceDate = "20260101"
    while !Task.isCancelled {
        switch try await client.realtime.delays(tripIds, serviceDate: serviceDate) {
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
    for try await update in client.realtime.pollVehicles(["T-1", "T-2"], intervalMs: 15_000) {
        if case .success(let positions) = update {
            for vehicle in positions.vehicles {
                placeMarker(lat: vehicle.latitude ?? 0, lon: vehicle.longitude ?? 0)
            }
        }
    }
    // [END pollHelper]
}

/// Fetch live vehicle positions for a set of trips.
func vehicles(client: SpiderClient) async throws {
    // [START vehicles]
    let result = try await client.realtime.vehicles(["T-1", "T-2"])
    if case .success(let positions) = result {
        for vehicle in positions.vehicles {
            print("\(vehicle.tripId ?? "?") at \(vehicle.latitude ?? 0),\(vehicle.longitude ?? 0)")
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
            placeMarker(lat: vehicle.latitude ?? 0, lon: vehicle.longitude ?? 0)
        } else {
            log("no vehicle currently reporting for \(tripId)")
        }
    }
    // [END vehicleForTrip]
}

/// Live schedule deviation for a set of trips, printed in minutes.
func delays(client: SpiderClient) async throws {
    // [START delays]
    // Delays are per trip instance — pass the GTFS service date (`YYYYMMDD`) the trips run on.
    let result = try await client.realtime.delays(["T-1", "T-2"], serviceDate: "20260101")
    if case .success(let trips) = result {
        for group in trips.groups {
            for delay in group.delays {
                let minutes = (delay.delaySeconds ?? 0) / 60
                let sign = minutes >= 0 ? "+" : ""
                print("\(delay.tripId ?? "?"): \(sign)\(minutes) min")
            }
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
