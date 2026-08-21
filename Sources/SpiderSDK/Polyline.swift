import Foundation

/// A decoded geographic point.
public struct LatLon: Sendable, Equatable {
    public let lat: Double
    public let lon: Double
    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

/// Decodes a Google-encoded polyline (precision 1e5) into points. Truncation-tolerant: a string that ends
/// mid-group returns the points decoded so far rather than throwing.
func decodePolyline(_ encoded: String) -> [LatLon] {
    let chars = Array(encoded.unicodeScalars)
    let count = chars.count
    var points: [LatLon] = []
    var index = 0
    var lat = 0
    var lon = 0

    func nextDelta() -> Int? {
        var result = 0
        var shift = 0
        var byte: Int
        repeat {
            if index >= count { return nil }
            byte = Int(chars[index].value) - 63
            index += 1
            result |= (byte & 0x1f) << shift
            shift += 5
        } while byte >= 0x20
        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }

    while index < count {
        guard let dLat = nextDelta() else { break }
        lat += dLat
        guard let dLon = nextDelta() else { break }
        lon += dLon
        points.append(LatLon(lat: Double(lat) / 1e5, lon: Double(lon) / 1e5))
    }
    return points
}
