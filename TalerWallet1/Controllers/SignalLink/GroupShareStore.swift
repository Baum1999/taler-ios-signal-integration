//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Merkt sich dauerhaft, zu welcher Gruppen-Zahlung (Split beim
/// compose-send) eine einzelne Transaktion gehört - reine lokale
/// UI-Zusatzinfo für die Sammelzeile der Transaktionsliste
/// (Android-Gegenstück: peer/GroupShareStore.kt). wallet-core kennt den
/// Gruppenbegriff nicht. `groupId` ist die correlationId des
/// Sende-Vorgangs, nicht die Signal-Gruppen-ID.
///
/// Schlüssel ist die transactionId (kein Inhaberpapier, anders als die
/// URI in OwnUriStore), Ablage im UserDefaults-Bereich der App unter
/// `signalLink.groupShares`.
final class GroupShareStore {

    static let shared = GroupShareStore()

    struct Info: Codable, Equatable {
        var groupId: String
        var index: Int
        var count: Int
        /// Hat sich der Ersteller beim Splitten mitgezählt? nil = unbekannt.
        var includeSelf: Bool?
    }

    private static let storeKey = "signalLink.groupShares"

    private let defaults: UserDefaults
    private let lock = NSLock()
    /// Zwischenspeicher, damit die Liste nicht bei jedem Rendern JSON dekodiert.
    private var cache: [String: Info]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Alle Anteile einer Gruppe auf einmal merken (Reihenfolge = index).
    /// Leere transactionIds werden übersprungen.
    func record(transactionIds: [String], groupId: String, includeSelf: Bool?) {
        guard !groupId.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var entries = loadEntries()
        for (index, transactionId) in transactionIds.enumerated() where !transactionId.isEmpty {
            entries[transactionId] = Info(groupId: groupId,
                                          index: index,
                                          count: transactionIds.count,
                                          includeSelf: includeSelf)
        }
        saveEntries(entries)
    }

    /// Gruppeninfo einer Transaktion, nil wenn sie zu keinem Split gehört.
    func info(forTransactionId transactionId: String) -> Info? {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries()[transactionId]
    }

    // MARK: - Persistenz

    private func loadEntries() -> [String: Info] {
        if let cache { return cache }
        let entries: [String: Info]
        if let data = defaults.data(forKey: Self.storeKey),
           let decoded = try? JSONDecoder().decode([String: Info].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
        cache = entries
        return entries
    }

    private func saveEntries(_ entries: [String: Info]) {
        cache = entries
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storeKey)
    }
}

#endif
