//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL
import UIKit

/// Baut die Rücksprung-Links zu Signal (Vertrag Abschnitt 8 und 9) und
/// öffnet sie. Ziel-Validierung und Query-Neuaufbau sind Pflicht
/// (Vertrag 2.6): eine im returnUri mitgeschickte Query wird immer
/// verworfen und komplett neu aufgebaut, damit keine Parameter
/// eingeschleust werden können.
enum ReturnURLBuilder {
    /// Scheme of the messenger's return target. The default is the official
    /// Signal app (`sgnl`); builds paired with a different messenger change
    /// it here and in LSApplicationQueriesSchemes of the Info.plist.
    static let returnScheme = "sgnl"
    static let returnBase = "\(returnScheme)://taler-return"

    /// Nur genau dieses Ziel löst einen Rücksprung aus: Scheme
    /// returnScheme, Host taler-return, kein User/Passwort/Port, leerer
    /// Pfad. Alles andere (z. B. sgnl://linkdevice) ist verboten -
    /// Taler darf kein Redirect-Gadget für fremde Signal-Deep-Links sein.
    /// Eine Query im returnUri ist hier erlaubt; sie wird beim
    /// Neuaufbau verworfen.
    static func isAllowedTarget(_ url: URL) -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = comps.scheme, scheme.lowercased() == returnScheme,
              let host = comps.host, host.lowercased() == "taler-return",
              comps.user == nil, comps.password == nil, comps.port == nil,
              comps.path.isEmpty
        else { return false }
        return true
    }

    /// status-Variante mit ready (Vertrag Abschnitt 8): correlationId,
    /// status, talerUri, optional talerPaymentData - in dieser Reihenfolge.
    static func ready(ctx: SignalReturnContext, talerUri: String, paymentDataJson: String?) -> URL {
        var parts: [String] = ["correlationId=" + encode(ctx.correlationId), "status=ready"]
        parts.append("talerUri=" + encode(talerUri))
        if let paymentDataJson {
            parts.append("talerPaymentData=" + encode(paymentDataJson))
        }
        return assembled(queryParts: parts)
    }

    /// status-Variante mit cancelled (Vertrag Abschnitt 8). talerUri und
    /// talerPaymentData werden bewusst nicht mitgeschickt.
    static func cancelled(ctx: SignalReturnContext) -> URL {
        assembled(queryParts: ["correlationId=" + encode(ctx.correlationId), "status=cancelled"])
    }

    /// result-Variante für compose-abort (Vertrag Abschnitt 9): pro URI ein
    /// result=<uri>|<ergebnis>, Reihenfolge wie im Anfrage-Link. Der gesamte
    /// Wert wird streng kodiert, also auch das '|' als %7C.
    static func abortResults(ctx: SignalReturnContext, results: [(uri: String, outcome: String)]) -> URL {
        var parts: [String] = ["correlationId=" + encode(ctx.correlationId)]
        for result in results {
            parts.append("result=" + encode(result.uri + "|" + result.outcome))
        }
        return assembled(queryParts: parts)
    }

    /// Öffnet den Rücksprung, falls das Ziel ein erlaubtes ist. Der Aufruf
    /// erfolgt nur über diese Stelle (Vertrag 2.5), niemals direkt mit
    /// UIApplication.open auf eine fremde URL.
    @MainActor
    static func open(_ url: URL) {
        guard isAllowedTarget(url) else { return }
        UIApplication.shared.open(url)
    }

    /// Ziel von "Nachricht in Signal zeigen" (Vertrag Abschnitt 12).
    static let openBase = "\(returnScheme)://taler-open"
    static let maxOpenHashes = 32

    /// taler-open-Link: v=1, dann je URI-Hash ein uriHash (64 Hex-Zeichen,
    /// klein), höchstens 32. Nur Hashes, nie die URI selbst - iOS kann nicht
    /// prüfen, welche App das Scheme registriert hat. nil ohne gültigen Hash.
    static func openPayment(uriHashes: [String]) -> URL? {
        var hashes: [String] = []
        for hash in uriHashes.map({ $0.lowercased() }) where !hashes.contains(hash) {
            guard hash.utf8.count == 64, hash.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { continue }
            hashes.append(hash)
            if hashes.count == maxOpenHashes { break }
        }
        guard !hashes.isEmpty else { return nil }
        let query = (["v=1"] + hashes.map { "uriHash=" + $0 }).joined(separator: "&")
        return URL(string: openBase + "?" + query)
    }

    /// Öffnet die Signal-Nachricht zu diesen eigenen Transaktionen (Einzel-
    /// zahlung oder alle Anteile eines Splits). false, wenn keine URI dazu
    /// bekannt ist - dann gibt es in Signal auch keine Nachricht.
    @MainActor
    @discardableResult
    static func openPaymentMessage(transactionIds: [String]) -> Bool {
        guard let url = openPayment(uriHashes: OwnUriStore.shared.uriHashes(forTransactionIds: transactionIds))
        else { return false }
        UIApplication.shared.open(url)
        return true
    }

    /// Setzt das Ziel neu zusammen: festes returnBase,
    /// danach die streng kodierten Parameter. Die Query des returnUri aus
    /// dem Anfrage-Link wird nie übernommen (Vertrag 2.6).
    private static func assembled(queryParts: [String]) -> URL {
        let query = queryParts.joined(separator: "&")
        // Alle Teile bestehen ausschließlich aus unreserved-Zeichen bzw.
        // gültigen %XX-Folgen, daher kann dieses Zusammenbauen nicht scheitern.
        return URL(string: returnBase + "?" + query)
            ?? URL(string: returnBase)!
    }

    /// Strenges Prozent-Kodieren (Vertrag 2.2): nur A-Za-z0-9-._~ bleiben
    /// roh, alles andere wird als %XX kodiert (UTF-8, Hex in Großbuchstaben).
    /// Insbesondere + & = / : ? # % | und Leerzeichen (%20, nie '+').
    static func encode(_ value: String) -> String {
        var encoded = ""
        encoded.reserveCapacity(value.utf8.count)
        for byte in value.utf8 {
            switch byte {
                case 0x41...0x5A, 0x61...0x7A, 0x30...0x39, 0x2D, 0x2E, 0x5F, 0x7E:    // A-Za-z0-9-._~
                    encoded.append(Character(UnicodeScalar(byte)))
                default:
                    encoded += "%" + String(format: "%02X", byte)
            }
        }
        return encoded
    }
}

#endif
