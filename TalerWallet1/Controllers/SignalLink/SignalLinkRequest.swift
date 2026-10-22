//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Rohe Query einer URL: Paare in Reihenfolge, wiederholte Parameter
/// bleiben erhalten (Vertrag 2.2). Dekodiert wird prozentweise streng:
/// ein rohes '+' bleibt '+' (niemals Leerzeichen), ungültige
/// Prozent-Folgen verwerfen nur das betroffene Paar.
struct SignalLinkQuery {
    private let pairs: [(name: String, value: String)]

    init(_ percentEncodedQuery: String?) {
        var result: [(name: String, value: String)] = []
        if let query = percentEncodedQuery, !query.isEmpty {
            for pair in query.split(separator: "&" as Character, omittingEmptySubsequences: true) {
                // Nur Paare mit "=" zählen; Namen sind case-sensitiv (Vertrag 2.2).
                guard let eq = pair.firstIndex(of: "=") else { continue }
                guard let name = String(pair[pair.startIndex..<eq]).removingPercentEncoding,
                      let value = String(pair[pair.index(after: eq)...]).removingPercentEncoding
                else { continue }
                result.append((name, value))
            }
        }
        pairs = result
    }

    /// Erster Wert des Parameters (Vertrag 2.3: bei Duplikaten gewinnt der erste).
    func first(_ name: String) -> String? {
        pairs.first { $0.name == name }?.value
    }

    /// Alle Werte eines wiederholbaren Parameters, Reihenfolge erhalten.
    func all(_ name: String) -> [String] {
        pairs.filter { $0.name == name }.map { $0.value }
    }
}

/// Richtung einer compose-send-Anfrage. Fehlt der Parameter oder ist er
/// unbekannt, gilt PAY_PUSH (Vertrag Abschnitt 3).
enum SignalLinkDirection: String {
    case payPush = "PAY_PUSH"
    case payPull = "PAY_PULL"
}

/// Kontext für den Rücksprung zu Signal (Vertrag 2.4): correlationId ist
/// nur ein Zuordnungs-Token, returnUri wurde bereits validiert.
struct SignalReturnContext {
    let correlationId: String
    let returnUri: URL
}

/// Parameter eines talerlink://compose-send-Links (Vertrag Abschnitt 3).
/// Alle Werte sind untrusted und dienen ausschließlich der Anzeige bzw.
/// als Anfangsstellung - nie für Entscheidungen über Geld (Vertrag 2.6).
///
/// TODO Avatar-Bild: Android bekommt ein Avatar-Feld im Protokoll
/// (content://-URI + grantUriPermission an TalerAllowlist.PACKAGE, siehe
/// TalerSendActions.kt). Fuer iOS war ein App-Group-Shared-Container als
/// Transportweg angedacht - das Entitlement steht erst mit einem
/// kostenpflichtigen Apple Developer Program-Account zur Verfuegung
/// (aktuell nur Personal-Team/kostenloser Account). Bis dahin bleibt
/// `avatar` hier bewusst aus, kommt wenn Apple Developer Program.
struct ComposeSendParams {
    let recipientHint: String?
    // Anzeigename der sendenden Messenger-App (z.B. "Signal"), vom Absender
    // selbst gesetzt, keine feste App-Liste - befuellt nur den
    // Vorschlagstext im Zweck-Feld (SignalComposeSendView.swift).
    let senderAppName: String?
    let isGroup: Bool
    let direction: SignalLinkDirection
    let disappearingMessagesSeconds: Int
    let memberCount: Int
    let ctx: SignalReturnContext
}

/// Flache Anzeige-Metadaten von compose-abort (spec-multi-uri-link.md
/// 3.1/3.2). Reine Anzeigehilfe aus Signal, untrusted: Taler entscheidet
/// nie auf ihrer Grundlage und zeigt Beträge nur aus den eigenen
/// Transaktionen. Ein ungültiger Wert verwirft nur dieses eine Feld,
/// unbekannte Parameter werden ignoriert.
struct AbortRequestMeta: Equatable {
    /// Schema-Version, fehlt = 1. Größere Werte werden trotzdem verarbeitet.
    var version = 1
    /// "delete" (Für alle löschen) oder "menu" (Abbrechen im Menü).
    var reason: String?
    var isGroup: Bool?
    var recipientHint: String?
    var memberCount: Int?
    var isGroupSplit: Bool?
    var includeSelf: Bool?
    var splitCount: Int?
    var currency: String?
    /// Dezimalstring ohne Währung, Format wie talerPaymentData.totalAmount.
    var totalAmount: String?
    var summary: String?
    /// Millisekunden seit 1970.
    var sentAt: UInt64?

    static let maxRecipientHintLength = 80
    static let maxSummaryLength = 200

    static func parse(_ query: SignalLinkQuery) -> AbortRequestMeta {
        var meta = AbortRequestMeta()
        if let v = query.first("v").flatMap({ Int($0) }), v >= 1 { meta.version = v }
        if let reason = query.first("reason"), reason == "delete" || reason == "menu" { meta.reason = reason }
        meta.isGroup = bool(query.first("isGroup"))
        meta.recipientHint = text(query.first("recipientHint"), max: maxRecipientHintLength)
        if meta.isGroup == true { meta.memberCount = positiveInt(query.first("memberCount")) }
        meta.isGroupSplit = bool(query.first("isGroupSplit"))
        meta.includeSelf = bool(query.first("includeSelf"))
        meta.splitCount = positiveInt(query.first("splitCount"))
        if let currency = query.first("currency"),
           (1...12).contains(currency.count),
           currency.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            meta.currency = currency.uppercased()
        }
        if let total = query.first("totalAmount"), isDecimal(total) { meta.totalAmount = total }
        meta.summary = text(query.first("summary"), max: maxSummaryLength)
        meta.sentAt = query.first("sentAt").flatMap { UInt64($0) }
        return meta
    }

    private static func bool(_ value: String?) -> Bool? {
        switch value {
            case "true": return true
            case "false": return false
            default: return nil
        }
    }

    private static func positiveInt(_ value: String?) -> Int? {
        guard let value, let number = Int(value), number >= 1 else { return nil }
        return number
    }

    private static func text(_ value: String?, max: Int) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
        else { return nil }
        return String(trimmed.prefix(max))
    }

    private static func isDecimal(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }
    }
}

/// Ein von Signal empfangener, bereits validierter talerlink://-Link.
enum SignalLinkRequest {
    case composeSend(ComposeSendParams)
    case composeRefund(originalUri: String, ctx: SignalReturnContext)
    /// `uris`: alle Eingangs-URIs, Dubletten zusammengefasst, Reihenfolge
    /// erhalten - auch ungültige und überzählige, denn jede bekommt ein
    /// Ergebnis (`failed`), siehe `isProcessable`.
    case composeAbort(uris: [String], meta: AbortRequestMeta, ctx: SignalReturnContext)
    case peerAction(talerUri: URL, ctx: SignalReturnContext)
}

extension SignalLinkRequest: Identifiable {
    /// Der Vorgang wird über die correlationId identifiziert.
    var id: String { correlationId }
}

extension SignalLinkRequest {
    /// Rücksprung-Kontext des Requests (jede Art führt genau einen mit).
    var ctx: SignalReturnContext {
        switch self {
            case .composeSend(let params): return params.ctx
            case .composeRefund(_, let ctx): return ctx
            case .composeAbort(_, _, let ctx): return ctx
            case .peerAction(_, let ctx): return ctx
        }
    }

    var correlationId: String { ctx.correlationId }
}

extension SignalLinkRequest {
    /// Parst einen talerlink://-Link. Bei jedem Regelverstoß wird nil
    /// zurückgegeben (still verworfen, Vertrag 2.3). Die URL wird niemals
    /// geloggt - jede pay-push/pay-pull-URI ist ein Inhaberpapier (Vertrag 2.6).
    static func parse(_ url: URL) -> SignalLinkRequest? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let scheme = comps.scheme, scheme.lowercased() == "talerlink" else { return nil }
        guard let host = comps.host else { return nil }
        let query = SignalLinkQuery(comps.percentEncodedQuery)

        // Pflicht-Kontext für jede Art: correlationId nicht leer, returnUri
        // muss ein erlaubtes Rücksprung-Ziel sein, sonst nil (Paket T1).
        guard let correlationId = query.first("correlationId"), !correlationId.isEmpty,
              let returnUriString = query.first("returnUri"), !returnUriString.isEmpty,
              let returnUri = URL(string: returnUriString),
              ReturnURLBuilder.isAllowedTarget(returnUri)
        else { return nil }
        let ctx = SignalReturnContext(correlationId: correlationId, returnUri: returnUri)

        switch host {
            case "compose-send":
                let direction = SignalLinkDirection(rawValue: query.first("direction") ?? "") ?? .payPush
                let isGroup = query.first("isGroup") == "true"
                let params = ComposeSendParams(
                    recipientHint: query.first("recipientHint"),
                    senderAppName: query.first("senderAppName"),
                    isGroup: isGroup,
                    direction: direction,
                    disappearingMessagesSeconds: nonNegativeInt(query.first("disappearingMessagesSeconds")),
                    memberCount: isGroup ? nonNegativeInt(query.first("memberCount")) : 0,
                    ctx: ctx)
                return .composeSend(params)

            case "compose-refund":
                guard let originalUri = query.first("originalUri"), !originalUri.isEmpty else { return nil }
                return .composeRefund(originalUri: originalUri, ctx: ctx)

            case "compose-abort":
                var seen = Set<String>()
                let uris = query.all("uri").filter { !$0.isEmpty && seen.insert($0).inserted }
                guard uris.indices.contains(where: { isProcessable(uris, at: $0) }) else { return nil }
                return .composeAbort(uris: uris, meta: AbortRequestMeta.parse(query), ctx: ctx)

            case "pay-push", "pay-pull":
                guard let talerUri = cleanedTalerUri(host: host, percentEncodedPath: comps.percentEncodedPath)
                else { return nil }
                return .peerAction(talerUri: talerUri, ctx: ctx)

            default:
                return nil
        }
    }

    /// Ganzzahl >= 0, robust: nicht parsbar oder negativ -> 0 (Vertrag 2.3).
    static func nonNegativeInt(_ value: String?) -> Int {
        guard let value,
              let number = Int(value.trimmingCharacters(in: .whitespaces)),
              number > 0
        else { return 0 }
        return number
    }

    /// Höchstens so viele URIs bearbeitet Taler je compose-abort
    /// (spec-multi-uri-link.md 3.1); Signal stapelt darüber.
    static let maxAbortUris = 32

    /// Wird die URI an Position `index` bearbeitet? Nur innerhalb der
    /// Obergrenze und nur abbrechbare URIs, alle anderen erhalten `failed`.
    static func isProcessable(_ uris: [String], at index: Int) -> Bool {
        index < maxAbortUris && isAbortableUri(uris[index])
    }

    /// Nur taler://pay-push/ und taler://pay-pull/ sind als abzubrechende
    /// URIs zulässig (case-insensitiv, Vertrag Abschnitt 5).
    static func isAbortableUri(_ uri: String) -> Bool {
        let lower = uri.lowercased()
        return lower.hasPrefix("taler://pay-push/") || lower.hasPrefix("taler://pay-pull/")
    }

    /// Baut aus einem talerlink://pay-*-Link die bereinigte taler://-URI:
    /// gleiches Host und Pfad, jegliche Query und Fragment entfernt
    /// (Vertrag Abschnitt 6). Nur diese bereinigte URI geht an wallet-core,
    /// niemals die talerlink-URL selbst. Unbekannte Query-Parameter fallen
    /// damit automatisch weg.
    static func cleanedTalerUri(host: String, percentEncodedPath: String) -> URL? {
        guard percentEncodedPath.count > 1 else { return nil }
        var comps = URLComponents()
        comps.scheme = "taler"
        comps.host = host
        comps.percentEncodedPath = percentEncodedPath
        return comps.url
    }
}

#endif
