import Foundation

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

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

func gtfsTimeSeconds(_ value: String) -> Int? {
    let parts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 3, (1...2).contains(parts[0].count), parts[1].count == 2, parts[2].count == 2,
          parts.allSatisfy({ $0.utf8.allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") } }),
          let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]), m < 60, s < 60 else { return nil }
    return h * 3600 + m * 60 + s
}
