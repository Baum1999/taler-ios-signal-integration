//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import CryptoKit

#if TALER_SIGNAL

/// Merkt sich zu jeder von diesem Gerät ERZEUGTEN Zahlungs-URI die
/// zugehörige wallet-core-Transaktion und ob sie Teil eines Gruppen-Splits
/// ist (Android-Gegenstück: link/OwnUriTracker.kt plus der Split-Marker
/// aus peer/GroupShareStore.kt). T5 (compose-abort) bildet damit eine URI
/// auf die eigene Transaktion ab und nutzt das zusätzlich zur
/// Transaktionssuche.
///
/// Ablage ist der UserDefaults-Bereich der App unter dem Präfix
/// `signalLink.` - wie Android in SharedPreferences: Speichern ist kein
/// Loggen (Eiserne Regel 4), die URI muss aber für den Abbruch dauerhaft
/// zuordenbar sein.
final class OwnUriStore {

    static let shared = OwnUriStore()

    /// Eintrag pro erzeugter URI.
    struct Entry: Codable, Equatable {
        var transactionId: String
        /// Nur bei Gruppen-Split gesetzt: correlationId des Sende-Vorgangs.
        var groupId: String?
    }

    /// Alles liegt unter diesem einen Schlüssel (Präfix signalLink.).
    private static let storeKey = "signalLink.ownUris"

    private let defaults: UserDefaults
    private let lock = NSLock()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// URI -> Transaktion merken; überschreibt einen bestehenden Eintrag.
    /// Leere Werte werden still verworfen.
    func record(uri: String, transactionId: String, groupId: String? = nil) {
        guard !uri.isEmpty, !transactionId.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var entries = loadEntries()
        entries[Self.key(for: uri)] = Entry(transactionId: transactionId, groupId: groupId)
        saveEntries(entries)
    }

    /// transactionId für eine selbst erzeugte URI, nil wenn unbekannt.
    func transactionId(forUri uri: String) -> String? {
        entry(forUri: uri)?.transactionId
    }

    /// Voller Eintrag (groupId zeigt die Split-Zugehörigkeit), nil wenn
    /// die URI nicht von diesem Gerät erzeugt wurde.
    func entry(forUri uri: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries()[Self.key(for: uri)]
    }

    /// Anzahl gemerkter Einträge (Diagnose, ohne URIs preiszugeben).
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries().count
    }

    // MARK: - Persistenz

    /// Schlüssel = SHA-256 (hex) der URI: eine pay-push/pay-pull-URI ist ein
    /// Inhaberpapier und darf nicht im Klartext auf der Platte liegen. Die
    /// öffentliche API (uri -> transactionId) bleibt unverändert.
    private static func key(for uri: String) -> String {
        SHA256.hash(data: Data(uri.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func loadEntries() -> [String: Entry] {
        guard let data = defaults.data(forKey: Self.storeKey),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return entries
    }

    private func saveEntries(_ entries: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storeKey)
    }
}

#endif
