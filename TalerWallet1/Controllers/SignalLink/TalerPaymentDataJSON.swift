//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// JSON-Paket `talerPaymentData` im Rücksprung von compose-send
/// (Vertrag docs/cross-platform/datenmodell.md Abschnitt 2,
/// Android-Gegenstück: link/TalerPaymentData.kt).
///
/// Feldnamen sind Protokoll und exakt: `legacyText`, `version`,
/// `includeSelf`, `totalAmount`, `uri` (Singular, obwohl Liste).
/// Android kodiert mit kotlinx.serialization (encodeDefaults=false):
/// Felder mit Standardwert (version = 1, null) werden weggelassen -
/// dieser Encoder erzeugt dasselbe Byte-Bild, damit beide Seiten
/// identisches JSON produzieren und der Android-Empfänger (der strikt
/// parst) keine Abweichung sieht.
struct SignalLinkPaymentData: Codable {

    /// Fallback-Text für Clients ohne Feld 9000 (Vertrag: heute englisch,
    /// identisch zu taler-android taler_payment_legacy_text).
    static let legacyText =
        "This is a GNU Taler link. Update Signal or copy the URI below into the GNU Taler app to make the payment."

    /// Fallback-Text für Clients ohne Feld 9000.
    var legacyText: String
    /// Split: Sender hat sich mitgezählt; nil = keine Split-Info.
    var includeSelf: Bool?
    /// Split: Gesamtbetrag vor dem Split als Dezimalstring ohne Währung
    /// (genau wie Android Amount.amountStr, z. B. "10" oder "12.5");
    /// nil = keine Split-Info.
    var totalAmount: String?
    /// Zahlungs-URIs. Einzelzahlung: 1 Element, Split: N.
    var uri: [String]
    /// Nur beim Dekodieren gelesen: roher version-Wert des JSON, nil wenn
    /// das Feld fehlt (Standard 1).
    private(set) var version: Int?

    /// Aufgelöste Format-Version: fehlt im JSON -> 1 (Vertrag).
    var resolvedVersion: Int { version ?? 1 }

    init(legacyText: String,
         includeSelf: Bool? = nil,
         totalAmount: String? = nil,
         uri: [String]) {
        self.legacyText = legacyText
        self.includeSelf = includeSelf
        self.totalAmount = totalAmount
        self.uri = uri
        self.version = 1
    }

    enum CodingKeys: String, CodingKey {
        case legacyText, version, includeSelf, totalAmount, uri
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        legacyText = try container.decode(String.self, forKey: .legacyText)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
        includeSelf = try container.decodeIfPresent(Bool.self, forKey: .includeSelf)
        totalAmount = try container.decodeIfPresent(String.self, forKey: .totalAmount)
        uri = try container.decode([String].self, forKey: .uri)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Feldreihenfolge wie die Kotlin-Deklaration (legacyText, version,
        // includeSelf, totalAmount, uri); version wird wie bei Android
        // (encodeDefaults=false, immer Standard 1) nie mitgesendet.
        try container.encode(legacyText, forKey: .legacyText)
        try container.encodeIfPresent(includeSelf, forKey: .includeSelf)
        try container.encodeIfPresent(totalAmount, forKey: .totalAmount)
        try container.encode(uri, forKey: .uri)
    }

    /// Kompaktes JSON wie Android es erzeugt; nil, wenn nicht kodierbar.
    func encodedJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Tolerantes Parsen (unbekannte Felder werden ignoriert, fehlende
    /// optionale Felder bleiben nil); nil bei ungültigem JSON.
    static func decodeJSON(_ json: String) -> SignalLinkPaymentData? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

#endif
