/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift

public class TalerDater: DateFormatter {
    public static let shared = TalerDater()

    static func relativeDate(from: TimeInterval) -> String? {
        if from > 0 {       // transactions should always be in the past
            let minute = from / 60.0                // from is in seconds
            if minute < 1 { return String(localized: "Right now") }
            if minute < 2 { return String(localized: "1 minute ago") }
            if minute < 55 { return String(localized: "\(Int(minute)) minutes ago") }
            if minute < 60 { return String(localized: "About an hour ago") }
            if minute < 80 { return String(localized: "1 hour ago") }
            if minute < 105 { return String(localized: "About 1½ hours ago") }
            if minute < 125 { return String(localized: "About 2 hours ago") }
            let hour = minute / 60.0
            let calendar = Calendar.current
            let now = Date.now
            let currHour = Double(calendar.component(.hour, from: now))
            let currMin = Double(calendar.component(.minute, from: now))
            let currTime = currHour + currMin/60
            if hour < currTime { return String(localized: "\(Int(hour)) hours ago") }
            if hour < currTime + 24 { return String(localized: "Yesterday") }
            let day = (hour - currTime) / 24.0
            if day < 7 { return String(localized: "\(Int(day+1)) days ago") }
            if day < 14 { return String(localized: "More than a week ago") }
            // will fall thru...
            return nil
        } else {            // Yikes❗️ transaction date is in the future
            return nil
        }
    }

    /// produces a random date string between `now` and m+h+d (edit values after 60x)
    public static func randomDateStr() -> String {
        let m =       60*15
        let h =    60*60*9
        let d = 24*60*60*22
        let t = m+h+d
        let randomTime = Int.random(in:1...t)
        if let randomDateStr = relativeDate(from: Double(randomTime)) {
            return randomDateStr
        } else {    // t is too large for a relative date
                    // return absolute date with random locale
            let localeStr = (randomTime&1 == 1) ? "de_DE" : "en_US"
            shared.locale = NSLocale(localeIdentifier: localeStr) as Locale
            let randomDate = Date(timeIntervalSinceNow: Double(-t))
            return shared.string(from: randomDate)
        }
    }

//    public static func date(from: Timestamp) -> Date {
//        let milliseconds = try from.milliseconds()
//        let date = Date(milliseconds: milliseconds)
//        return date
//    }

    /// converts a timestamp into a formatted date string
    public static func dateString(from: Timestamp, relative: Bool = false) -> (String, Date?) {
        do {
            let milliseconds = try from.milliseconds()
            let date = Date(milliseconds: milliseconds)

            if relative {
                let now = Date.now
                let timeInterval = now.timeIntervalSince(date)
                if let relativeDate = relativeDate(from: timeInterval) {
                    return (relativeDate, date)
                }
            }
            return (shared.string(from: date), date)
        } catch {       // Never
            let never = String(localized: "No date", comment: "Timestamp missing or invalid")
            return (never, nil)
        }
    }

    public static func dateString() -> String {
        return shared.string(from: Date())
    }

    private override init() {
        super.init()
        self.setLocalizedDateFormatFromTemplate("EEEdMMM")        // abbreviated day of week
        self.dateStyle = .medium
        self.timeStyle = .short
//        self.timeZone = TimeZone(abbreviation: "UTC")         // UTC prints GMT
//        self.dateFormat = "z yyyy-MM-dd HH:mm"                // "GMT 2022-11-09 18:00"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
extension TimeInterval {

    var seconds: Int {
        return Int(self.rounded())
    }

    var milliseconds: Int {
        return Int(self * 1000)
    }
}
