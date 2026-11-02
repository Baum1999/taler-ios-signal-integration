//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

#if TALER_SIGNAL

/// Wer hat die Zahlung angestoßen: Chat-Name, Gruppen-Flag und Name der
/// sendenden App, wie sie beim compose-send-Link ankamen. Alle Texte sind
/// angreiferkontrolliert und werden vor dem Speichern bereinigt.
struct SignalContact: Codable, Equatable {
    var name: String?
    var isGroup: Bool
    var appName: String?
    /// Dateiname der verkleinerten Avatar-Kopie, nil = Platzhalter.
    var avatarFile: String?
}

/// Merkt sich pro transactionId den Signal-Kontakt, der die Zahlung ausgelöst
/// hat - lokale UI-Zusatzinfo für Transaktionsliste und Detailansicht
/// (Android-Gegenstück: ContactStore.kt, android-nachzieh-liste.md N19).
/// wallet-core kennt den Kontext nicht. Die Avatar-Kopie ist nötig, weil die
/// Datei im gemeinsamen Container nur für den Übergabe-Moment existiert.
///
/// Ablage: Einträge in UserDefaults unter `signalLink.contacts`, Avatare als
/// JPEG in Application Support/signal-contacts (ein Avatar pro Vorgang,
/// von allen Gruppenanteilen geteilt).
final class SignalContactStore {

    static let shared = SignalContactStore()

    private static let storeKey = "signalLink.contacts"
    private static let folderName = "signal-contacts"

    private let defaults: UserDefaults
    private let folder: URL
    private let lock = NSLock()
    private var cache: [String: SignalContact]?

    init(defaults: UserDefaults = .standard, folder: URL? = nil) {
        self.defaults = defaults
        self.folder = folder ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.folderName, isDirectory: true)
    }

    /// Kontakt für alle Transaktionen eines Vorgangs merken (Einzelzahlung
    /// oder alle Gruppenanteile). `avatarJPEG` wird einmal abgelegt und von
    /// allen Einträgen geteilt. Leere transactionIds werden übersprungen.
    func record(transactionIds: [String], contact: SignalContact, avatarKey: String, avatarJPEG: Data?) {
        let ids = transactionIds.filter { !$0.isEmpty }
        guard !ids.isEmpty else { return }
        var contact = contact
        contact.avatarFile = nil
        if let avatarJPEG, !avatarKey.isEmpty {
            let fileName = Self.safeFileName(avatarKey) + ".jpg"
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try avatarJPEG.write(to: folder.appendingPathComponent(fileName), options: .atomic)
                contact.avatarFile = fileName
            } catch {
                // Avatar ist rein kosmetisch: ohne Datei bleibt der Platzhalter.
            }
        }
        lock.lock()
        defer { lock.unlock() }
        var entries = loadEntries()
        for id in ids { entries[id] = contact }
        saveEntries(entries)
    }

    /// Kontakt einer Transaktion, nil wenn sie nicht über Signal entstand.
    func contact(forTransactionId transactionId: String) -> SignalContact? {
        lock.lock()
        defer { lock.unlock() }
        return loadEntries()[transactionId]
    }

    func avatar(for contact: SignalContact) -> UIImage? {
        guard let file = contact.avatarFile else { return nil }
        return UIImage(contentsOfFile: folder.appendingPathComponent(file).path)
    }

    private static func safeFileName(_ key: String) -> String {
        String(key.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    }

    private func loadEntries() -> [String: SignalContact] {
        if let cache { return cache }
        let entries: [String: SignalContact]
        if let data = defaults.data(forKey: Self.storeKey),
           let decoded = try? JSONDecoder().decode([String: SignalContact].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
        cache = entries
        return entries
    }

    private func saveEntries(_ entries: [String: SignalContact]) {
        cache = entries
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storeKey)
    }
}

/// Liest den von Signal im gemeinsamen App-Group-Ordner abgelegten Avatar
/// (`avatarFile` im compose-send-Link, link-protokoll.md 3). Der Gruppenname
/// steht im Info.plist-Schlüssel `TalerShareAppGroup` (Fork-Konfiguration);
/// fehlt er, gibt es keinen Avatar und alles andere läuft unverändert.
/// Die Datei ist angreiferkontrolliert: nur ein einfacher Dateiname, Größen-
/// grenze, Dekodierung über ImageIO mit Pixelgrenze, Neukodierung als JPEG.
enum SignalSharedAvatar {

    static let groupInfoKey = "TalerShareAppGroup"
    static let folderName = "taler-compose-avatars"
    static let maxFileBytes = 512 * 1024
    static let targetPixels = 96

    /// Nur `<A-Za-z0-9_-.>` mit `.jpg`, keine Pfadanteile.
    static func isValidFileName(_ name: String) -> Bool {
        name.range(of: #"^[A-Za-z0-9_-]{1,64}\.jpg$"#, options: .regularExpression) != nil
    }

    private static func fileURL(_ name: String) -> URL? {
        guard isValidFileName(name),
              let group = Bundle.main.object(forInfoDictionaryKey: groupInfoKey) as? String,
              !group.isEmpty,
              let container = FileManager.default
                  .containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        return container.appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(name)
    }

    /// Verkleinertes JPEG (≤ 96 px) oder nil. Löscht die Quelle nicht.
    static func load(fileName: String?) -> Data? {
        guard let fileName, let url = fileURL(fileName),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int, size > 0, size <= maxFileBytes,
              let data = try? Data(contentsOf: url)
        else { return nil }
        return downscaledJPEG(from: data)
    }

    /// Quelle entfernen, sobald sie übernommen wurde.
    static func remove(fileName: String?) {
        guard let fileName, let url = fileURL(fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func downscaledJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }
}

#endif
