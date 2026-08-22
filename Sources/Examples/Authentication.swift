import Foundation
import SpiderSDK

/// Keep the API key out of source: read it from the environment at startup.
func authenticated() -> SpiderClient {
    // [START authenticated]
    let apiKey = ProcessInfo.processInfo.environment["SPIDER_API_KEY"] ?? ""
    let client = SpiderClient(
        baseURL: "https://your-env-slug.api.tiducto.eu",
        apiKey: apiKey
    )
    // [END authenticated]
    return client
}

/// Each environment has its own hostname and its own key — construct one client per environment.
func targeting() -> (SpiderClient, SpiderClient) {
    // [START targeting]
    let staging = SpiderClient(
        baseURL: "https://acme-staging.api.tiducto.eu",
        apiKey: "staging-key"
    )
    let production = SpiderClient(
        baseURL: "https://acme-production.api.tiducto.eu",
        apiKey: "production-key"
    )
    // [END targeting]
    return (staging, production)
}
