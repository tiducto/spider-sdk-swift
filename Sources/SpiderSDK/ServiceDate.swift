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
