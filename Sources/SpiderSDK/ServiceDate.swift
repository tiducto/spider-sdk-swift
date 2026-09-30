import Foundation

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

// The GTFS service date (`YYYY-MM-DD`) of a wire `serviceDay` (epoch seconds of the service day's noon-minus-12h
// reference). Adding 12h lands on the service day's own noon, whose UTC calendar date is the service date for
// any agency zone within ±12h — including a night trip whose times run past 24:00.
func isoServiceDate(ofServiceDay serviceDay: Int) -> String {
    let parts = utcCalendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: TimeInterval(serviceDay + 43_200)))
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

// True for an ISO `YYYY-MM-DD` naming a real calendar day.
func isServiceDate(_ value: String) -> Bool {
    let chars = Array(value.utf8)
    guard chars.count == 10, chars[4] == UInt8(ascii: "-"), chars[7] == UInt8(ascii: "-") else { return false }
    for (i, c) in chars.enumerated() where i != 4 && i != 7 {
        guard c >= UInt8(ascii: "0") && c <= UInt8(ascii: "9") else { return false }
    }
    guard let year = Int(value.prefix(4)),
          let month = Int(value.dropFirst(5).prefix(2)),
          let day = Int(value.suffix(2)) else { return false }
    return DateComponents(year: year, month: month, day: day).isValidDate(in: utcCalendar)
}
