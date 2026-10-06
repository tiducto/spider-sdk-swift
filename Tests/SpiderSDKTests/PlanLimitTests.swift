import XCTest
@testable import SpiderSDK

/// Guards the gateway's plan-limit refusals: the body's `planning_limit_reached` or `agreement_inactive` decides the
/// error on every surface, whatever the HTTP status, and carries the body's message. A 403 without one of them
/// stays unauthorized. The plan stream's pre-stream refusal is covered in RoutingStreamTests.
final class PlanLimitTests: XCTestCase {
    private let planningLimitBody = #"{"error":"planning_limit_reached","message":"trip planning limit reached"}"#
    private let agreementBody = #"{"error":"agreement_inactive","message":"agreement is not active"}"#

    private static let surfaces = [
        "plan", "departures", "trip", "stops.search", "stops.byId",
        "realtime.vehicles", "realtime.vehicleForTrip", "realtime.delays", "realtime.alerts",
    ]

    // Every surface's failure for one canned response, in `surfaces` order.
    private func surfaceErrors(_ response: MockHTTPClient.Response) async throws -> [(String, SpiderError)] {
        let (client, _) = makeClient { _ in response }
        var errors: [(String, SpiderError)] = []
        func record<T>(_ name: String, _ result: SpiderResult<T>) {
            guard case .failure(let error) = result else { return XCTFail("\(name): expected failure") }
            errors.append((name, error))
        }
        record("plan", try await client.routing.plan(PlanOptions(origin: .stop("A"), destination: .stop("B"))))
        record("departures", try await client.routing.departures("S"))
        record("trip", try await client.routing.trip("T"))
        record("stops.search", try await client.stops.search(StopFilter(name: "Main")))
        do {
            _ = try await client.stops.byId("S")
            XCTFail("stops.byId: expected failure")
        } catch let error as SpiderError {
            errors.append(("stops.byId", error))
        }
        record("realtime.vehicles", try await client.realtime.vehicles(["T1"]))
        record("realtime.vehicleForTrip", try await client.realtime.vehicleForTrip("T1"))
        record("realtime.delays", try await client.realtime.delays(["T1"], serviceDate: "2026-01-01"))
        record("realtime.alerts", try await client.realtime.alerts())
        XCTAssertEqual(errors.map(\.0), Self.surfaces)
        return errors
    }

    func testPlanningLimitReachedOn403OnEverySurface() async throws {
        for (surface, error) in try await surfaceErrors(json(planningLimitBody, status: 403)) {
            XCTAssertEqual(error.code, .planningLimitReached, surface)
            XCTAssertEqual(error.code.rawValue, "planning_limit_reached", surface)
            XCTAssertEqual(error.httpStatus, 403, surface)
            XCTAssertEqual(error.serverCode, "planning_limit_reached", surface)
            XCTAssertEqual(error.message, "trip planning limit reached", surface)
            XCTAssertNil(error.field, surface)
        }
    }

    func testAgreementInactiveOn403OnEverySurface() async throws {
        for (surface, error) in try await surfaceErrors(json(agreementBody, status: 403)) {
            XCTAssertEqual(error.code, .agreementInactive, surface)
            XCTAssertEqual(error.code.rawValue, "agreement_inactive", surface)
            XCTAssertEqual(error.httpStatus, 403, surface)
            XCTAssertEqual(error.serverCode, "agreement_inactive", surface)
            XCTAssertEqual(error.message, "agreement is not active", surface)
            XCTAssertNil(error.field, surface)
        }
    }

    func testPlanLimitCodeIsReadFromCodeOrError() async throws {
        let bodies: [(body: String, code: SpiderErrorCode)] = [
            (#"{"code":"planning_limit_reached","message":"trip planning limit reached"}"#, .planningLimitReached),
            (#"{"code":"agreement_inactive","error":"agreement_inactive","message":"agreement is not active"}"#, .agreementInactive),
            (#"{"code":"forbidden","error":"planning_limit_reached","message":"access denied"}"#, .unauthorized),
        ]
        for (body, code) in bodies {
            for (surface, error) in try await surfaceErrors(json(body, status: 403)) {
                XCTAssertEqual(error.code, code, "\(surface) with body \(body)")
                XCTAssertEqual(error.httpStatus, 403, surface)
            }
        }
    }

    // A proxy may rewrite the status: the body code still decides, over the 400/404/410/500 mappings and over the
    // realtime by-trip 404 that otherwise means "no vehicle". The rewritten status is carried as received.
    func testBodyCodeWinsOverRewrittenStatus() async throws {
        let cases: [(body: String, code: SpiderErrorCode, message: String)] = [
            (planningLimitBody, .planningLimitReached, "trip planning limit reached"),
            (agreementBody, .agreementInactive, "agreement is not active"),
        ]
        for (body, code, message) in cases {
            for status in [400, 401, 404, 410, 429, 500] {
                for (surface, error) in try await surfaceErrors(json(body, status: status)) {
                    let label = "\(surface) on \(status)"
                    XCTAssertEqual(error.code, code, label)
                    XCTAssertEqual(error.httpStatus, status, label)
                    XCTAssertEqual(error.serverCode, code.rawValue, label)
                    XCTAssertEqual(error.message, message, label)
                    XCTAssertNil(error.field, label)
                }
            }
        }
    }

    // No status-only fallback: a 403 whose body names neither code stays unauthorized.
    func testPlain403StaysUnauthorized() async throws {
        let bodies = [
            "",
            "forbidden",
            #"{"error":"forbidden","message":"access denied"}"#,
            #"{"message":"trip planning limit reached"}"#,
        ]
        for body in bodies {
            for (surface, error) in try await surfaceErrors(json(body, status: 403)) {
                let label = "\(surface) with body \(body)"
                XCTAssertEqual(error.code, .unauthorized, label)
                XCTAssertEqual(error.httpStatus, 403, label)
                XCTAssertNotEqual(error.serverCode, "planning_limit_reached", label)
                XCTAssertNotEqual(error.serverCode, "agreement_inactive", label)
            }
        }
    }

    // The message is the body's own, trimmed; a body whose message is missing or blank falls back to the code's
    // fixed wording.
    func testMessageIsTheBodyMessage() async throws {
        let custom = #"{"error":"agreement_inactive","message":" the agreement for this project is not active\n"}"#
        for (surface, error) in try await surfaceErrors(json(custom, status: 403)) {
            XCTAssertEqual(error.code, .agreementInactive, surface)
            XCTAssertEqual(error.message, "the agreement for this project is not active", surface)
        }
        let fallbacks: [(body: String, code: SpiderErrorCode, message: String)] = [
            (#"{"error":"planning_limit_reached"}"#, .planningLimitReached, "trip planning limit reached"),
            (#"{"error":"planning_limit_reached","message":""}"#, .planningLimitReached, "trip planning limit reached"),
            (#"{"error":"agreement_inactive","message":"  "}"#, .agreementInactive, "agreement is not active"),
        ]
        for (body, code, message) in fallbacks {
            for (surface, error) in try await surfaceErrors(json(body, status: 403)) {
                let label = "\(surface) with body \(body)"
                XCTAssertEqual(error.code, code, label)
                XCTAssertEqual(error.message, message, label)
            }
        }
    }
}
