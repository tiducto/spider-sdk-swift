import Foundation

private let DEFAULT_POLL_INTERVAL_MS = 15_000

/// Change-detecting realtime polling. Each stream calls the underlying surface on an interval and yields a
/// value only when the result changes (by value equality) from the previous one. Cancel the consuming task
/// (or break out of the `for await`) to stop polling — the stream finishes without throwing on cancel. A major
/// contract mismatch throws out of the stream.
extension SpiderRealtime {
    /// Polls `vehicles(_:)`.
    public func pollVehicles(_ tripIds: [String], intervalMs: Int? = nil) -> AsyncThrowingStream<SpiderResult<VehiclePositions>, Error> {
        poll(intervalMs: intervalMs) { try await self.vehicles(tripIds) }
    }

    /// Polls `vehicleForTrip(_:)`.
    public func pollVehicleForTrip(_ tripId: String, intervalMs: Int? = nil) -> AsyncThrowingStream<SpiderResult<LiveVehicleUpdate>, Error> {
        poll(intervalMs: intervalMs) { try await self.vehicleForTrip(tripId) }
    }

    /// Polls `delays(_:)`.
    public func pollDelays(_ tripIds: [String], intervalMs: Int? = nil) -> AsyncThrowingStream<SpiderResult<TripDelays>, Error> {
        poll(intervalMs: intervalMs) { try await self.delays(tripIds) }
    }

    /// Polls `alerts()`.
    public func pollAlerts(intervalMs: Int? = nil) -> AsyncThrowingStream<SpiderResult<ServiceAlerts>, Error> {
        poll(intervalMs: intervalMs) { try await self.alerts() }
    }
}

private func poll<T: Equatable>(
    intervalMs: Int?,
    _ fetch: @escaping () async throws -> SpiderResult<T>
) -> AsyncThrowingStream<SpiderResult<T>, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            let interval = UInt64(max(0, intervalMs ?? DEFAULT_POLL_INTERVAL_MS)) * 1_000_000
            var last: SpiderResult<T>?
            while !Task.isCancelled {
                do {
                    let result = try await fetch()
                    if last == nil || !resultsEqual(last!, result) {
                        last = result
                        continuation.yield(result)
                    }
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                if Task.isCancelled { break }
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    break // cancelled during the wait
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

// Consecutive results are de-duplicated: success compares data by value, failure compares code + message.
private func resultsEqual<T: Equatable>(_ a: SpiderResult<T>, _ b: SpiderResult<T>) -> Bool {
    switch (a, b) {
    case let (.success(x), .success(y)):
        return x == y
    case let (.failure(x), .failure(y)):
        return x.code == y.code && x.message == y.message
    default:
        return false
    }
}
