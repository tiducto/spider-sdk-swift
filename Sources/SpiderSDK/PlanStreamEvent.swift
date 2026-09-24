import Foundation

/// One event from `SpiderRouting.planStream`. The router sweeps the search window forward and pushes
/// itineraries as they finalize: zero or more `chunk`s, a `page` with the continuation cursors, then a
/// terminal `done`. A `failure` is terminal and takes the place of the rest — it is never thrown, it is the
/// last event the stream yields.
public enum PlanStreamEvent {
    /// A batch of finalized itineraries as the search frontier advances. Each `Itinerary`'s legs carry the
    /// scheduled times plus the realtime delay fields (`startEstimated` / `endEstimated` /
    /// `startDelaySeconds` / `endDelaySeconds` / `isRealtime` / `realtimeState`) — the same delay handling
    /// the one-shot `plan` applies. `frontierSeconds` is how far (seconds from the search start) the window
    /// has swept; `found` is the running count discovered and `finalized` the count committed so far.
    case chunk(frontierSeconds: Int, found: Int, finalized: Int, itineraries: [Itinerary])

    /// Continuation cursors for the stream, mirroring `Route.pageInfo`. Re-call `planStream` with the same
    /// inputs plus `after` = `RoutePageInfo.endCursor` to stream the next window (or `before` =
    /// `RoutePageInfo.startCursor` for the previous one).
    case page(RoutePageInfo)

    /// Terminal summary once the sweep stops: how many `iterations` ran, the window reached in
    /// `windowSeconds`, the total `resultCount`, and why it `stoppedBy` (e.g. `targetResults` or `maxWindow`).
    case done(iterations: Int, windowSeconds: Int, resultCount: Int, stoppedBy: String)

    /// Terminal failure — a transport/HTTP problem, a decoding error, or a server `error` event (e.g. an
    /// invalid request). Carries the same `SpiderError` taxonomy the one-shot calls return.
    case failure(SpiderError)
}
