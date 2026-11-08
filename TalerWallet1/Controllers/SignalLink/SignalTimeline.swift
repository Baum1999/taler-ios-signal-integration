//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

/// Wie lange eine offene P2P-Zahlung noch gilt. Warnstufe in den letzten 5 %
/// der Laufzeit (Laufzeit = Erstellung bis Ablauf), danach "abgelaufen" -
/// wallet-core setzt den Zustand erst kurz darauf auf expired.
enum SignalExpiry: Equatable {
    case normal(String)
    case warning(String)
    case expired

    static let warningFraction = 0.05

    static func evaluate(start: Date?, end: Date, now: Date) -> SignalExpiry {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return .expired }
        let text = remainingText(seconds: remaining)
        if let start {
            let total = end.timeIntervalSince(start)
            if total > 0, remaining <= total * warningFraction {
                return .warning(text)
            }
        }
        return .normal(text)
    }

    /// "noch 28 Tage gültig", ab 48 h in Tagen, ab 2 h in Stunden, sonst in
    /// Minuten (abgerundet). Unter einer Minute "läuft gleich ab".
    static func remainingText(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        guard minutes >= 1 else { return "läuft gleich ab" }
        let hours = minutes / 60
        var components = DateComponents()
        if hours >= 48 {
            components.day = hours / 24
        } else if hours >= 2 {
            components.hour = hours
        } else {
            components.minute = minutes
        }
        let amount = formatter.string(from: components) ?? ""
        return "noch \(amount) gültig"
    }

    /// Die Signal-Integration ist deutschsprachig (wie "gesamt", "Anteile"),
    /// daher auch die Einheiten auf Deutsch - sonst entstünde "noch 3 days".
    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter
    }()

    static func date(_ timestamp: Timestamp?) -> Date? {
        guard let timestamp, let milliseconds = try? timestamp.milliseconds() else { return nil }
        return Date(milliseconds: milliseconds)
    }
}

/// Zeitzeile "vor 5 Minuten · noch 28 Tage gültig" für Zahlungen aus Signal:
/// steht ganz unten in der Zeile, unter der Signal-Kontaktzeile. Die
/// Ablaufangabe erscheint nur bei `expiration != nil` (offene P2P-Zahlung);
/// in den letzten 5 % der Laufzeit in Warnfarbe.
struct SignalTimeline: View {
    let timestamp: Timestamp
    let expiration: Timestamp?
    let textColor: Color

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let (dateString, start) = TalerDater.dateString(timestamp, minimalistic, relative: true)
            (Text(dateString).foregroundColor(textColor) + expiryText(start: start, now: context.date))
                .talerFont(.callout)
        }
    }

    private func expiryText(start: Date?, now: Date) -> Text {
        guard let end = SignalExpiry.date(expiration) else { return Text(verbatim: "") }
        switch SignalExpiry.evaluate(start: start, end: end, now: now) {
            case .normal(let text):
                return Text(verbatim: " · \(text)").foregroundColor(.secondary)
            case .warning(let text):
                return Text(verbatim: " · \(text)").foregroundColor(.orange)
            case .expired:
                return Text(verbatim: " · abgelaufen").foregroundColor(WalletColors().attention)
        }
    }
}

#endif
