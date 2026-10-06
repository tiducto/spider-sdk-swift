import Foundation

/// One event from a plan stream (`SpiderRouting.planStream` / `planStreamNext` / `planStreamPrevious`). The
/// router sweeps the search window and pushes itineraries as they finalize: zero or more `result` events, then
/// a terminal `done` carrying the continuation cursors and any routing errors. A `failure` is terminal and takes
/// the place of the rest — it is never thrown, it is the last event the stream yields.
public enum PlanStreamEvent {
    /// The terminal outcome of a stream: the continuation cursors plus the routing errors, as on a batch `Route`.
    public struct Done: Sendable, Equatable {
        /// Mirrors `Route.pageInfo`. Read `endCursor` (when `hasNextPage`) and continue with
        /// `planStreamNext(..., after:)`, or `startCursor` (when `hasPreviousPage`) and continue with
        /// `planStreamPrevious(..., before:)`.
        public let pageInfo: RoutePageInfo
        /// Why the sweep found nothing, or found less than it could (e.g. `.outsideServicePeriod`,
        /// `.locationNotFound`) — the same routing errors a batch `plan` returns on `Route.routingErrors`.
        /// Empty when there are none.
        public let routingErrors: [RoutingError]
    }

    /// A batch of finalized itineraries as the search frontier advances. Each `Itinerary`'s legs carry the
    /// scheduled times plus the realtime delay fields (`startEstimated` / `endEstimated` /
    /// `startDelaySeconds` / `endDelaySeconds` / `isRealtime` / `realtimeState`) — the same delay handling
    /// the one-shot `plan` applies.
    case result([Itinerary])

    /// Terminal: the continuation cursors and routing errors.
    case done(Done)

    /// Terminal failure — an input the SDK rejects before sending, a transport/HTTP problem (including a stream
    /// that ends before `done`), a decoding error, or a server error for an invalid request. Carries the same
    /// `SpiderError` taxonomy the one-shot calls return.
    case failure(SpiderError)
}
