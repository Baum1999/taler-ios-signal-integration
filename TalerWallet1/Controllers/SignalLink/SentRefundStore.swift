//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import CryptoKit

#if TALER_SIGNAL

/// Merkt sich dauerhaft, für welche empfangene Zahlung (originalUri aus dem
/// compose-refund-Link) bereits erfolgreich eine Rückerstattung erzeugt
/// wurde (Android-Gegenstück: link/SentRefundStore.kt - dort keyed by
/// originalTransactionId; iOS hat die Transaktion erst nach der Suche und
/// keyed deshalb nach Paket-Vorgabe mit dem SHA-256 der URI).
///
/// Ablage ist der UserDefaults-Bereich der App unter dem Präfix
/// `signalLink.sentRefund.` - der Schlüssel ist NUR der Hash, die URI
/// selbst steht weder im Schlüssel noch im Wert (Inhaberpapier, Eiserne
/// Regel 4: nie loggen - Speichern zum Schutz vor Doppelerstattung ist
/// erlaubt, darf die URI aber nicht im Klartext ablegen).
///
/// Bewusst dauerhaft und überschreibend (kein Verlauf, nur die letzte
/// tatsächlich gesendete Erstattung zählt) - siehe
/// SignalComposeRefundView für den "Verwerfen und neu erstellen"-Ablauf,
/// der einen bestehenden Eintrag erst überschreibt, wenn die neue
/// Erstattung tatsächlich gesendet wird.
final class SentRefundStore {

    static let shared = SentRefundStore()

    /// Eine bereits gesendete Erstattung.
    struct Entry: Equatable {
        var refundTransactionId: String
        var sentAt: Date
    }

    /// Schlüssel-Präfix in UserDefaults.
    private static let keyPrefix = "signalLink.sentRefund."
    /// Trennzeichen im Wert: "<refundTransactionId>|<Sekunden seit 1970>".
    /// Wie Android (SentRefundStore.kt) einfach und ohne JSON-Overhead.
    private static let valueSeparator: Character = "|"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// UserDefaults-Schlüssel für eine originalUri: Präfix plus SHA-256
    /// (Hex, Kleinbuchstaben) der UTF-8-Bytes. Die URI erscheint nirgends
    /// im Schlüssel. Leere URI -> nil (wird dann auch nicht gespeichert).
    static func storageKey(forOriginalUri uri: String) -> String? {
        guard !uri.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(uri.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return keyPrefix + hex
    }

    /// Bereits gesendete Erstattung für diese originalUri, nil wenn keine.
    func entry(forOriginalUri uri: String) -> Entry? {
        guard let key = Self.storageKey(forOriginalUri: uri),
              let stored = defaults.string(forKey: key)
        else { return nil }
        let parts = stored.split(separator: Self.valueSeparator, maxSplits: 1,
                                 omittingEmptySubsequences: false)
        guard parts.count == 2,
              let seconds = Double(String(parts[1]))
        else { return nil }
        return Entry(refundTransactionId: String(parts[0]),
                     sentAt: Date(timeIntervalSince1970: seconds))
    }

    /// Erstattung für diese originalUri merken; überschreibt einen
    /// bestehenden Eintrag. Leere Werte werden still verworfen.
    func markSent(originalUri: String, refundTransactionId: String, at sentAt: Date = Date()) {
        guard let key = Self.storageKey(forOriginalUri: originalUri),
              !refundTransactionId.isEmpty
        else { return }
        let value = refundTransactionId + String(Self.valueSeparator)
            + String(sentAt.timeIntervalSince1970)
        defaults.set(value, forKey: key)
    }
}

#endif
