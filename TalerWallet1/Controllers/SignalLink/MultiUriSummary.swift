//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import taler_swift

#if TALER_SIGNAL

/// Sammelkarte für mehrere in einer Einfügung gefundene taler://-URIs, z. B.
/// ein aus Signal kopierter Gruppen-Split (Android-Gegenstück:
/// link/MultiUriSummary.kt, Anzeige in ScanQrScreen.kt).
///
/// Bewusst "nicht mehr verfügbar" statt "X von N angenommen": wallet-core
/// meldet für eine fremde, bereits geclaimte Purse denselben Fehler wie für
/// eine abgebrochene oder abgelaufene (WALLET_PEER_PUSH_CREDIT_PURSE_GONE).
/// Ein echtes "angenommen" über fremde Anteile kennt nur das Absendergerät.

enum ShareState: Equatable {
    /// Wartet auf eine Entscheidung des Nutzers (wallet-core: dialog).
    case open
    /// Von DIESER Wallet bereits angenommen (wallet-core: done).
    case acceptedByMe
    /// Angenommen von anderen, abgebrochen, abgelaufen oder nicht prüfbar.
    case unavailable
}

struct SharePreview {
    var state: ShareState
    var amount: Amount?
    var exchangeBaseUrl: String?
}

struct ShareSummary: Identifiable {
    let uri: String
    /// Eigene ausgehende Zahlung (OwnUriStore): kein Anteil aus Empfängersicht.
    let isOwn: Bool
    let preview: SharePreview?
    var id: String { uri }
}

struct MultiUriAggregate {
    let total: Int
    let unavailable: Int
    let acceptedByMe: Int
    let open: [ShareSummary]
    /// Summe über offene und von mir angenommene Anteile, nur wenn alle einen
    /// Betrag in derselben Währung liefern.
    let totalAmount: Amount?
}

enum MultiUriSummary {

    /// Nur pay-push wird abgefragt: andere Arten haben in einem Gruppen-Split
    /// keine Bedeutung, und ein prepare* für fremde Vorgänge hätte
    /// Nebenwirkungen. Eigene URIs werden nie präpariert.
    static func build(uris: [String],
                      isOwn: (String) -> Bool,
                      preview: (String) async -> SharePreview?) async -> MultiUriAggregate {
        var shares: [ShareSummary] = []
        var seen = Set<String>()
        for uri in uris where seen.insert(uri).inserted {
            let own = isOwn(uri)
            let result = (!own && isPayPush(uri)) ? await preview(uri) : nil
            shares.append(ShareSummary(uri: uri, isOwn: own, preview: result))
        }
        let relevant = shares.filter { !$0.isOwn }
        let accepted = relevant.filter { $0.preview?.state == .acceptedByMe }
        let open = relevant.filter { $0.preview?.state == .open }
        return MultiUriAggregate(total: relevant.count,
                                 unavailable: relevant.count - accepted.count - open.count,
                                 acceptedByMe: accepted.count,
                                 open: open,
                                 totalAmount: totalAmount(of: open + accepted))
    }

    /// Nur wenn JEDER Anteil einen Betrag hat und alle dieselbe Währung
    /// tragen, sonst nil: lieber keine Summe als eine falsche.
    static func totalAmount(of shares: [ShareSummary]) -> Amount? {
        guard !shares.isEmpty else { return nil }
        var sum = Decimal(0)
        var currency: String?
        for share in shares {
            guard let amount = share.preview?.amount else { return nil }
            if let currency, currency != amount.currencyStr { return nil }
            currency = amount.currencyStr
            sum += Decimal(amount.integer) + Decimal(amount.fraction) / Decimal(100_000_000)
        }
        guard let currency else { return nil }
        return try? Amount(fromString: "\(currency):\(sum)")
    }

    static func isPayPush(_ uri: String) -> Bool {
        URL(string: uri)?.host?.lowercased() == "pay-push"
    }

    /// Art, Exchange-Host und Ende der URI statt der rohen URI: der Host
    /// bleibt sichtbar (Phishing-Schutz), die URI ist ein Inhaberpapier.
    static func label(for share: ShareSummary) -> String {
        let kind: String
        switch URL(string: share.uri)?.host?.lowercased() {
            case "pay-push": kind = "Push"
            case "pay-pull": kind = "Pull"
            case "pay": kind = "Pay"
            case "withdraw": kind = "Withdraw"
            case "refund": kind = "Refund"
            default: kind = "?"
        }
        let host = share.preview?.exchangeBaseUrl.flatMap { URL(string: $0)?.host }
        return [kind, host, "…" + share.uri.suffix(6)].compactMap { $0 }.joined(separator: " · ")
    }
}

#endif

#if TALER_SIGNAL && DEBUG

extension SignalLinkSelfCheck {

    /// Prüft die Aggregation der Sammelkarte. Rückgabe: fehlgeschlagene Fälle
    /// (leer = ok). Wird wie `run()` vom Reviewer ausgeführt.
    static func runMultiUri() async -> [String] {
        var failed: [String] = []
        func expect(_ name: String, _ condition: Bool) { if !condition { failed.append(name) } }
        func amount(_ s: String) -> Amount? { try? Amount(fromString: s) }

        let open1 = "taler://pay-push/ex.example/AAAAAA"
        let open2 = "taler://pay-push/ex.example/BBBBBB"
        let gone = "taler://pay-push/ex.example/CCCCCC"
        let mine = "taler://pay-push/ex.example/DDDDDD"
        let previews: [String: SharePreview] = [
            open1: SharePreview(state: .open, amount: amount("KUDOS:1.5")),
            open2: SharePreview(state: .open, amount: amount("KUDOS:2.25")),
            gone: SharePreview(state: .unavailable),
        ]
        var prepared: [String] = []
        let agg = await MultiUriSummary.build(
            uris: [open1, open2, gone, mine, open1],
            isOwn: { $0 == mine },
            preview: { prepared.append($0); return previews[$0] })

        expect("Dublette und eigene URI zählen nicht", agg.total == 3)
        expect("eigene URI wird nicht präpariert", !prepared.contains(mine))
        expect("ein Anteil nicht verfügbar", agg.unavailable == 1)
        expect("zwei offene Anteile", agg.open.count == 2)
        expect("Summe 3.75 nur über offene", agg.totalAmount?.readableDescription == amount("KUDOS:3.75")?.readableDescription)

        let mixed = await MultiUriSummary.build(
            uris: [open1, open2], isOwn: { _ in false },
            preview: { $0 == open1 ? SharePreview(state: .open, amount: amount("KUDOS:1")) : SharePreview(state: .open, amount: amount("EUR:1")) })
        expect("gemischte Währungen: keine Summe", mixed.totalAmount == nil)

        let accepted = await MultiUriSummary.build(
            uris: [open1], isOwn: { _ in false },
            preview: { _ in SharePreview(state: .acceptedByMe, amount: amount("KUDOS:1")) })
        expect("angenommen gezählt", accepted.acceptedByMe == 1 && accepted.open.isEmpty)

        let notPush = await MultiUriSummary.build(
            uris: ["taler://withdraw/ex.example/X"], isOwn: { _ in false },
            preview: { prepared.append($0); return SharePreview(state: .open) })
        expect("withdraw wird nicht präpariert", !prepared.contains("taler://withdraw/ex.example/X") && notPush.unavailable == 1)

        return failed
    }
}

#endif
