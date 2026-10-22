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
/// Feldnamen sind Protokoll und exakt: `version`, `includeSelf`,
/// `totalAmount`, `uri` (Singular, obwohl Liste). Kein `legacyText`
/// (mehr): den Klartext vor den URIs setzt seit 2026-10-11 der Messenger
/// selbst; ein mitgeschicktes `legacyText` älterer Versionen wird beim
/// Dekodieren ignoriert.
/// Android kodiert mit kotlinx.serialization (encodeDefaults=false):
/// Felder mit Standardwert (version = 1, null) werden weggelassen -
/// dieser Encoder erzeugt dasselbe Byte-Bild, damit beide Seiten
/// identisches JSON produzieren und der Android-Empfänger (der strikt
/// parst) keine Abweichung sieht.
struct SignalLinkPaymentData: Codable {

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

    init(includeSelf: Bool? = nil,
         totalAmount: String? = nil,
         uri: [String]) {
        self.includeSelf = includeSelf
        self.totalAmount = totalAmount
        self.uri = uri
        self.version = 1
    }

    enum CodingKeys: String, CodingKey {
        case version, includeSelf, totalAmount, uri
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
        includeSelf = try container.decodeIfPresent(Bool.self, forKey: .includeSelf)
        totalAmount = try container.decodeIfPresent(String.self, forKey: .totalAmount)
        uri = try container.decode([String].self, forKey: .uri)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Feldreihenfolge wie die Kotlin-Deklaration (version, includeSelf,
        // totalAmount, uri); version wird wie bei Android
        // (encodeDefaults=false, immer Standard 1) nie mitgesendet.
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
