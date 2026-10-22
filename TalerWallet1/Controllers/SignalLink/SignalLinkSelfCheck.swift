//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL && DEBUG

/// Selbstprüfung der talerlink-Infrastruktur gegen den Link-Vertrag
/// (docs/cross-platform/link-protokoll.md). Wird NICHT automatisch
/// aufgerufen - der Reviewer führt sie aus (in diesem Slot gibt es
/// keinen Testlauf für taler-ios).
enum SignalLinkSelfCheck {

    /// Prüft Parser, Ziel-Validierung und Query-Neuaufbau. Rückgabe ist
    /// die Liste der fehlgeschlagenen Fälle (leer = alles ok).
    static func run() -> [String] {
        var failed: [String] = []

        func expect(_ name: String, _ condition: Bool) {
            if !condition { failed.append(name) }
        }

        let rid = "6f1c2a34-8b1e-4d7a-9c55-0e8f3b2a1d90"
        let rid2 = "0b6c9f52-31d8-4a0f-8a3e-6d2c5e7f9a11"
        let ret = "\(ReturnURLBuilder.returnScheme)%3A%2F%2Ftaler-return"
        let base = "correlationId=\(rid)&returnUri=\(ret)"

        // ---- compose-send ----

        // 1) Minimaler Link: alles Standard, keine Pflichtverletzungen.
        if case .composeSend(let p)? = SignalLinkRequest.parse(u("talerlink://compose-send?\(base)")) {
            expect("compose-send minimal: PAY_PUSH", p.direction == .payPush)
            expect("compose-send minimal: isGroup false", p.isGroup == false)
            expect("compose-send minimal: Timer 0", p.disappearingMessagesSeconds == 0)
            expect("compose-send minimal: kein Hint", p.recipientHint == nil)
            expect("compose-send minimal: correlationId", p.ctx.correlationId == rid)
        } else { expect("compose-send minimal: geparst", false) }

        // 2) Alle Parameter, korrekt dekodiert.
        let sendFull = "talerlink://compose-send?recipientHint=Anna%20M%C3%BCller"
            + "&isGroup=true&direction=PAY_PULL&disappearingMessagesSeconds=86400"
            + "&\(base)&memberCount=5"
        if case .composeSend(let p)? = SignalLinkRequest.parse(u(sendFull)) {
            expect("compose-send vollständig: Hint dekodiert", p.recipientHint == "Anna Müller")
            expect("compose-send vollständig: isGroup true", p.isGroup == true)
            expect("compose-send vollständig: PAY_PULL", p.direction == .payPull)
            expect("compose-send vollständig: Timer 86400", p.disappearingMessagesSeconds == 86400)
            expect("compose-send vollständig: memberCount 5", p.memberCount == 5)
        } else { expect("compose-send vollständig: geparst", false) }

        // 3) direction fehlt oder ist unbekannt -> PAY_PUSH.
        if case .composeSend(let p)? = SignalLinkRequest.parse(u("talerlink://compose-send?direction=WITHDRAW&\(base)")) {
            expect("compose-send direction unbekannt -> PAY_PUSH", p.direction == .payPush)
        } else { expect("compose-send direction unbekannt: geparst", false) }

        // 4) isGroup: nur exakt "true" ist wahr.
        if case .composeSend(let p)? = SignalLinkRequest.parse(u("talerlink://compose-send?isGroup=TRUE&\(base)")) {
            expect("compose-send isGroup=TRUE -> false", p.isGroup == false)
            expect("compose-send isGroup=TRUE -> memberCount 0", p.memberCount == 0)
        } else { expect("compose-send isGroup=TRUE: geparst", false) }

        // 5) Zahlen robust: nicht parsbar -> 0, nie Absturz.
        if case .composeSend(let p)? = SignalLinkRequest.parse(u("talerlink://compose-send?isGroup=true&disappearingMessagesSeconds=abc&\(base)&memberCount=-3")) {
            expect("compose-send Timer abc -> 0", p.disappearingMessagesSeconds == 0)
            expect("compose-send memberCount -3 -> 0", p.memberCount == 0)
        } else { expect("compose-send Zahlen robust: geparst", false) }

        // 6) Kodierung von + & = #: '+' bleibt Plus (kein Leerzeichen).
        let sendEnc = "talerlink://compose-send?recipientHint=a%2Bb%26c%3Dd%23e&\(base)"
        if case .composeSend(let p)? = SignalLinkRequest.parse(u(sendEnc)) {
            expect("compose-send Kodierung +&=# zurück", p.recipientHint == "a+b&c=d#e")
        } else { expect("compose-send Kodierung: geparst", false) }

        // 7) Doppelte correlationId: der erste gewinnt (Vertrag 2.3).
        if case .composeSend(let p)? = SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=aaaa&\(base)")) {
            expect("compose-send Duplikat: erster gewinnt", p.ctx.correlationId == "aaaa")
        } else { expect("compose-send Duplikat: geparst", false) }

        // 8) Fehlende bzw. leere Pflichtparameter -> nil.
        expect("compose-send ohne correlationId -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?returnUri=\(ret)")) == nil)
        expect("compose-send leere correlationId -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=&returnUri=\(ret)")) == nil)
        expect("compose-send ohne returnUri -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=\(rid)")) == nil)

        // 9) returnUri: fremdes oder falsches Ziel -> nil (kein Redirect-Gadget).
        expect("fremdes returnUri-Scheme sgnl -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=\(rid)&returnUri=sgnl%3A%2F%2Flinkdevice%3Fa%3Db")) == nil)
        expect("returnUri falscher Host -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=\(rid)&returnUri=\(ReturnURLBuilder.returnScheme)%3A%2F%2Fother")) == nil)
        expect("returnUri mit Pfad -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=\(rid)&returnUri=\(ReturnURLBuilder.returnScheme)%3A%2F%2Ftaler-return%2Fx")) == nil)
        expect("returnUri mit User/Port -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-send?correlationId=\(rid)&returnUri=\(ReturnURLBuilder.returnScheme)%3A%2F%2Fuser%40taler-return%3A80")) == nil)

        // 10) Eingeschleuste Query im returnUri wird beim Neuaufbau verworfen.
        let injected = "talerlink://compose-send?correlationId=\(rid)"
            + "&returnUri=\(ReturnURLBuilder.returnScheme)%3A%2F%2Ftaler-return%3Fstatus%3Dready%26talerUri%3Devil"
        if case .composeSend(let p)? = SignalLinkRequest.parse(u(injected)) {
            let back = ReturnURLBuilder.cancelled(ctx: p.ctx).absoluteString
            expect("Query-Neuaufbau: eingeschleuste Params weg",
                   back == "\(ReturnURLBuilder.returnScheme)://taler-return?correlationId=\(rid)&status=cancelled")
            expect("Query-Neuaufbau: Ziel erlaubt", ReturnURLBuilder.isAllowedTarget(u(back)))
        } else { expect("Query-Neuaufbau: geparst", false) }

        // ---- compose-refund ----

        // 11) Gültiger Refund-Link.
        let refund = "talerlink://compose-refund?originalUri=taler%3A%2F%2Fpay-push%2Fexchange.example.org%2F7Q4XK2"
            + "&correlationId=\(rid2)&returnUri=\(ret)"
        if case .composeRefund(let originalUri, let c)? = SignalLinkRequest.parse(u(refund)) {
            expect("compose-refund: originalUri dekodiert",
                   originalUri == "taler://pay-push/exchange.example.org/7Q4XK2")
            expect("compose-refund: correlationId", c.correlationId == rid2)
        } else { expect("compose-refund: geparst", false) }
        expect("compose-refund ohne originalUri -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-refund?\(base)")) == nil)

        // ---- compose-abort ----

        // 12) Ungültige URIs bleiben drin (sie erhalten später `failed`),
        // Reihenfolge bleibt, Dubletten werden zusammengefasst.
        let abort = "talerlink://compose-abort?v=1&uri=taler%3A%2F%2Fpay-push%2Fexchange.example.org%2FAAAA"
            + "&uri=taler%3A%2F%2Fpay%2Fexchange.example.org%2FXXXX"
            + "&uri=taler%3A%2F%2Fpay-pull%2Fexchange.example.org%2FBBBB"
            + "&uri=taler%3A%2F%2Fpay-push%2Fexchange.example.org%2FAAAA&\(base)"
        if case .composeAbort(let uris, let meta, _)? = SignalLinkRequest.parse(u(abort)) {
            expect("compose-abort: alle URIs, Dublette zusammengefasst",
                   uris == ["taler://pay-push/exchange.example.org/AAAA",
                            "taler://pay/exchange.example.org/XXXX",
                            "taler://pay-pull/exchange.example.org/BBBB"])
            expect("compose-abort: ungültige URI nicht bearbeitbar",
                   !SignalLinkRequest.isProcessable(uris, at: 1)
                   && SignalLinkRequest.isProcessable(uris, at: 0))
            expect("compose-abort: ohne Metadaten leer", meta == AbortRequestMeta())
        } else { expect("compose-abort: geparst", false) }

        // 13) Case-insensitives Präfix (TALER://PAY-PUSH/), v fehlt = 1.
        let abortCase = "talerlink://compose-abort?uri=TALER%3A%2F%2FPAY-PUSH%2Fexchange.example.org%2FCCCC&\(base)"
        if case .composeAbort(let uris, let meta, _)? = SignalLinkRequest.parse(u(abortCase)) {
            expect("compose-abort: Präfix case-insensitiv", SignalLinkRequest.isProcessable(uris, at: 0))
            expect("compose-abort: v fehlt = 1", meta.version == 1)
        } else { expect("compose-abort case: geparst", false) }

        // 14) Nur ungültige bzw. gar keine URIs -> nil.
        expect("compose-abort alle URIs ungültig -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-abort?uri=taler%3A%2F%2Fpay%2Fexchange.example.org%2FXXXX&\(base)")) == nil)
        expect("compose-abort ohne uri -> nil",
               SignalLinkRequest.parse(u("talerlink://compose-abort?\(base)")) == nil)

        // 14a) Obergrenze 32: die 33. URI wird nicht bearbeitet.
        let many = (0..<33).map { "uri=taler%3A%2F%2Fpay-push%2Fe%2FK\($0)" }.joined(separator: "&")
        if case .composeAbort(let uris, _, _)? = SignalLinkRequest.parse(u("talerlink://compose-abort?\(many)&\(base)")) {
            expect("compose-abort: 33 URIs übernommen", uris.count == 33)
            expect("compose-abort: 32. bearbeitbar", SignalLinkRequest.isProcessable(uris, at: 31))
            expect("compose-abort: 33. nicht bearbeitbar", !SignalLinkRequest.isProcessable(uris, at: 32))
        } else { expect("compose-abort 33: geparst", false) }

        // 14b) Metadaten: flach, einzeln validiert, Texte gekürzt.
        let longHint = String(repeating: "h", count: 90)
        let withMeta = "talerlink://compose-abort?v=2&uri=taler%3A%2F%2Fpay-push%2Fe%2FA"
            + "&reason=delete&isGroup=true&recipientHint=\(longHint)&memberCount=4"
            + "&isGroupSplit=true&includeSelf=false&splitCount=abc&currency=kudos"
            + "&totalAmount=12.5&summary=Pizza%20%26%20Bier&sentAt=1760000000000&unknown=x&\(base)"
        if case .composeAbort(_, let meta, _)? = SignalLinkRequest.parse(u(withMeta)) {
            expect("meta: v=2 übernommen", meta.version == 2)
            expect("meta: reason", meta.reason == "delete")
            expect("meta: isGroup", meta.isGroup == true)
            expect("meta: recipientHint gekürzt", meta.recipientHint?.count == AbortRequestMeta.maxRecipientHintLength)
            expect("meta: memberCount", meta.memberCount == 4)
            expect("meta: includeSelf false", meta.includeSelf == false)
            expect("meta: ungültiges splitCount verworfen", meta.splitCount == nil)
            expect("meta: currency", meta.currency == "KUDOS")
            expect("meta: totalAmount", meta.totalAmount == "12.5")
            expect("meta: summary dekodiert", meta.summary == "Pizza & Bier")
            expect("meta: sentAt", meta.sentAt == 1_760_000_000_000)
        } else { expect("compose-abort mit Metadaten: geparst", false) }
        let badMeta = "talerlink://compose-abort?uri=taler%3A%2F%2Fpay-push%2Fe%2FA"
            + "&reason=boom&isGroup=ja&memberCount=0&totalAmount=1.2.3&currency=K%C3%9CDOS&\(base)"
        if case .composeAbort(_, let meta, _)? = SignalLinkRequest.parse(u(badMeta)) {
            expect("meta: ungültige Werte einzeln verworfen", meta == AbortRequestMeta())
        } else { expect("compose-abort mit ungültigen Metadaten: geparst", false) }

        // ---- peerAction (pay-push / pay-pull) ----

        // 15) Query wird vollständig entfernt, unbekannte Parameter ebenso.
        let peerPush = "talerlink://pay-push/exchange.example.org/7Q4XK2"
            + "?correlationId=\(rid)&returnUri=\(ret)&foo=bar"
        if case .peerAction(let talerUri, let c)? = SignalLinkRequest.parse(u(peerPush)) {
            expect("peerAction pay-push: Query entfernt",
                   talerUri.absoluteString == "taler://pay-push/exchange.example.org/7Q4XK2")
            expect("peerAction pay-push: correlationId", c.correlationId == rid)
        } else { expect("peerAction pay-push: geparst", false) }

        // 16) pay-pull analog, zusätzlich ein rohes Fragment-ähnliches Pfadende.
        let peerPull = "talerlink://pay-pull/exchange.example.org/9W2ZK4?correlationId=\(rid2)&returnUri=\(ret)"
        if case .peerAction(let talerUri, _)? = SignalLinkRequest.parse(u(peerPull)) {
            expect("peerAction pay-pull: Query entfernt",
                   talerUri.absoluteString == "taler://pay-pull/exchange.example.org/9W2ZK4")
        } else { expect("peerAction pay-pull: geparst", false) }

        // 17) peerAction ohne Kontext bzw. ohne Pfad -> nil.
        expect("peerAction ohne correlationId -> nil",
               SignalLinkRequest.parse(u("talerlink://pay-push/exchange.example.org/X?returnUri=\(ret)")) == nil)
        expect("peerAction leerer Pfad -> nil",
               SignalLinkRequest.parse(u("talerlink://pay-push?\(base)")) == nil)

        // ---- Scheme und Host ----

        // 18) talerlink case-insensitiv, taler:// mit compose-Host abgelehnt.
        expect("Scheme TALERLINK wird angenommen",
               SignalLinkRequest.parse(u("TALERLINK://compose-send?\(base)")) != nil)
        expect("Scheme taler mit compose-Host -> nil",
               SignalLinkRequest.parse(u("taler://compose-send?\(base)")) == nil)
        expect("unbekannter Host -> nil",
               SignalLinkRequest.parse(u("talerlink://withdraw?\(base)")) == nil)
        expect("Ruecksprung-Link wird nicht als talerlink geparst",
               SignalLinkRequest.parse(u("\(ReturnURLBuilder.returnScheme)://taler-return?correlationId=\(rid)")) == nil)

        // ---- ReturnURLBuilder ----

        let ctx = SignalReturnContext(correlationId: rid, returnUri: u("\(ReturnURLBuilder.returnScheme)://taler-return"))

        // 19) isAllowedTarget direkt.
        expect("isAllowedTarget: korrektes Ziel", ReturnURLBuilder.isAllowedTarget(u("\(ReturnURLBuilder.returnScheme)://taler-return")))
        expect("isAllowedTarget: Query erlaubt (wird verworfen)",
               ReturnURLBuilder.isAllowedTarget(u("\(ReturnURLBuilder.returnScheme)://taler-return?a=b")))
        expect("isAllowedTarget: sgnl abgelehnt", !ReturnURLBuilder.isAllowedTarget(u("sgnl://linkdevice?x=1")))
        expect("isAllowedTarget: Port abgelehnt", !ReturnURLBuilder.isAllowedTarget(u("\(ReturnURLBuilder.returnScheme)://taler-return:80")))
        expect("isAllowedTarget: Pfad abgelehnt", !ReturnURLBuilder.isAllowedTarget(u("\(ReturnURLBuilder.returnScheme)://taler-return/x")))

        // 20) ready: exakter Aufbau inkl. strenger Kodierung.
        let ready = ReturnURLBuilder.ready(ctx: ctx,
                                           talerUri: "a+b&c=d#e",
                                           paymentDataJson: "{\"uri\":[\"taler://pay-push/e.org/AAA\"]}")
        expect("ready: exakte URL",
               ready.absoluteString == "\(ReturnURLBuilder.returnScheme)://taler-return?correlationId=\(rid)"
               + "&status=ready&talerUri=a%2Bb%26c%3Dd%23e"
               + "&talerPaymentData=%7B%22uri%22%3A%5B%22taler%3A%2F%2Fpay-push%2Fe.org%2FAAA%22%5D%7D")
        expect("ready: Ziel erlaubt", ReturnURLBuilder.isAllowedTarget(ready))

        // 21) cancelled: exakt, ohne talerUri/talerPaymentData.
        let cancelled = ReturnURLBuilder.cancelled(ctx: ctx)
        expect("cancelled: exakte URL",
               cancelled.absoluteString == "\(ReturnURLBuilder.returnScheme)://taler-return?correlationId=\(rid)&status=cancelled")
        expect("cancelled: Ziel erlaubt", ReturnURLBuilder.isAllowedTarget(cancelled))

        // 22) abortResults: | als %7C, Reihenfolge erhalten.
        let results: [(uri: String, outcome: String)] = [
            ("taler://pay-push/e.org/AAAA", "aborted"),
            ("taler://pay-push/e.org/BBBB", "already_claimed"),
        ]
        let abortUrl = ReturnURLBuilder.abortResults(ctx: ctx, results: results)
        expect("abortResults: exakte URL",
               abortUrl.absoluteString == "\(ReturnURLBuilder.returnScheme)://taler-return?correlationId=\(rid)"
               + "&result=taler%3A%2F%2Fpay-push%2Fe.org%2FAAAA%7Caborted"
               + "&result=taler%3A%2F%2Fpay-push%2Fe.org%2FBBBB%7Calready_claimed")
        expect("abortResults: Ziel erlaubt", ReturnURLBuilder.isAllowedTarget(abortUrl))

        // 23) Kodierer: '%' selbst und Umlaute.
        expect("encode: % wird %25", ReturnURLBuilder.encode("100%") == "100%25")
        expect("encode: Umlaut UTF-8", ReturnURLBuilder.encode("ü") == "%C3%BC")
        expect("encode: unreserved bleiben roh", ReturnURLBuilder.encode("aZ09-._~") == "aZ09-._~")

        // ---- T3: splitAmountEvenly (AmountSplit.swift) ----

        // Erwartete Werte arithmetisch statt über Decimal(string:) gebaut -
        // unabhängig von Locale-Einstellungen des Geräts.
        let thirdFloor = Decimal(333_333_333) / Decimal(100_000_000)
        let thirdOfOneFloor = Decimal(33_333_333) / Decimal(100_000_000)

        // 24) Anteil abgerundet (FLOOR) auf 8 Nachkommastellen.
        expect("split(10, 3) = 3.33333333",
               AmountSplit.splitAmountEvenly(total: Decimal(10), parts: 3) == thirdFloor)
        expect("split(1, 3) = 0.33333333",
               AmountSplit.splitAmountEvenly(total: Decimal(1), parts: 3) == thirdOfOneFloor)
        expect("split(10, 2) = 5",
               AmountSplit.splitAmountEvenly(total: Decimal(10), parts: 2) == Decimal(5))
        expect("split(10, 4) = 2.5",
               AmountSplit.splitAmountEvenly(total: Decimal(10), parts: 4)
                   == Decimal(25) / Decimal(10))

        // 25) Ungültige Eingaben -> nil (parts < 1 oder total <= 0).
        expect("split(0, 2) = nil",
               AmountSplit.splitAmountEvenly(total: Decimal(0), parts: 2) == nil)
        expect("split(5, 0) = nil",
               AmountSplit.splitAmountEvenly(total: Decimal(5), parts: 0) == nil)
        expect("split(-1, 2) = nil",
               AmountSplit.splitAmountEvenly(total: Decimal(-1), parts: 2) == nil)
        expect("split(5, -3) = nil",
               AmountSplit.splitAmountEvenly(total: Decimal(5), parts: -3) == nil)

        // 26) FLOOR: Summe der Anteile übersteigt nie den Gesamtbetrag.
        if let share = AmountSplit.splitAmountEvenly(total: Decimal(10), parts: 3) {
            expect("split: 3 Anteile uebersteigen Total nie",
                   (share * 3) <= Decimal(10))
        } else { expect("split(10, 3) geparst", false) }

        // ---- T3: TalerPaymentDataJSON (SignalLinkPaymentData) ----

        // 27) Einzelzahlung: exakt wie Android (kotlinx,
        // encodeDefaults=false) - nur uri, kein legacyText mehr.
        let single = SignalLinkPaymentData(uri: ["taler://pay-push/e.org/AAA"])
        let singleJSON = "{\"uri\":[\"taler://pay-push/e.org/AAA\"]}"
        expect("JSON Einzelzahlung: exakter Aufbau", single.encodedJSON() == singleJSON)

        // 28) Split: includeSelf und totalAmount nur beim Split,
        // Feldnamen exakt (uri im Singular, Reihenfolge wie Android).
        let split = SignalLinkPaymentData(includeSelf: true,
                                         totalAmount: "10",
                                         uri: ["taler://pay-push/e.org/AAA",
                                               "taler://pay-push/e.org/BBBB"])
        let splitJSON = "{\"includeSelf\":true,"
            + "\"totalAmount\":\"10\","
            + "\"uri\":[\"taler://pay-push/e.org/AAA\",\"taler://pay-push/e.org/BBBB\"]}"
        expect("JSON Split: exakter Aufbau", split.encodedJSON() == splitJSON)

        // 29) Roundtrip MIT optionalen Feldern.
        if let back = SignalLinkPaymentData.decodeJSON(split.encodedJSON() ?? "") {
            expect("JSON Split Roundtrip: includeSelf", back.includeSelf == true)
            expect("JSON Split Roundtrip: totalAmount", back.totalAmount == "10")
            expect("JSON Split Roundtrip: uri", back.uri == ["taler://pay-push/e.org/AAA",
                                                             "taler://pay-push/e.org/BBBB"])
            expect("JSON Split Roundtrip: version Standard 1", back.resolvedVersion == 1)
        } else { expect("JSON Split Roundtrip: dekodierbar", false) }

        // 30) Roundtrip OHNE optionale Felder (Beispiel aus
        // datenmodell.md, identisch zu Android).
        let androidExample = "{\"uri\":[\"taler://pay-push/exchange.example.org/7Q4XK2\"]}"
        if let back = SignalLinkPaymentData.decodeJSON(androidExample) {
            expect("JSON Android-Beispiel: uri",
                   back.uri == ["taler://pay-push/exchange.example.org/7Q4XK2"])
            expect("JSON ohne Optionale: includeSelf nil", back.includeSelf == nil)
            expect("JSON ohne Optionale: totalAmount nil", back.totalAmount == nil)
            expect("JSON ohne version: Standard 1", back.resolvedVersion == 1)
            expect("JSON Roundtrip: identisch kodiert", back.encodedJSON() == androidExample)
        } else { expect("JSON Android-Beispiel: geparst", false) }

        // 31) Tolerant gegen unbekannte Felder und version explizit.
        expect("JSON mit Zusatzfeld dekodierbar",
               SignalLinkPaymentData.decodeJSON(
                   "{\"legacyText\":\"x\",\"uri\":[\"taler://pay-push/e/1\"],\"isGroupSplit\":true}"
               )?.uri == ["taler://pay-push/e/1"])
        if let withVersion = SignalLinkPaymentData.decodeJSON(
            "{\"legacyText\":\"x\",\"version\":2,\"uri\":[\"taler://pay-push/e/2\"]}") {
            expect("JSON version gelesen", withVersion.resolvedVersion == 2)
        } else { expect("JSON mit version: geparst", false) }

        // 32) Altes JSON mit legacyText (aeltere Versionen) bleibt lesbar,
        // wird aber ohne legacyText neu kodiert.
        if let old = SignalLinkPaymentData.decodeJSON(
            "{\"legacyText\":\"x\",\"uri\":[\"taler://pay-push/e/3\"]}") {
            expect("JSON alt: uri", old.uri == ["taler://pay-push/e/3"])
            expect("JSON alt: ohne legacyText kodiert",
                   old.encodedJSON() == "{\"uri\":[\"taler://pay-push/e/3\"]}")
        } else { expect("JSON alt mit legacyText: geparst", false) }
        // ---- T2: Vergleichsschlüssel eigene Zahlung (OwnTransactionLookup) ----

        // 24) Scheme in Kleinbuchstaben, Query und Fragment entfernt.
        expect("matchKey: Scheme klein",
               signalUriMatchKey("TALER://pay-push/exchange.example.org/7Q4XK2")
                   == signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2"))
        expect("matchKey: Query entfernt",
               signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2?x=1")
                   == signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2"))
        expect("matchKey: Fragment entfernt",
               signalUriMatchKey("taler://pay-pull/exchange.example.org/9W2ZK4#frag")
                   == signalUriMatchKey("taler://pay-pull/exchange.example.org/9W2ZK4"))
        expect("matchKey: exakter Wert",
               signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2")
                   == "taler://pay-push/exchange.example.org/7Q4XK2")
        expect("matchKey: pay-pull vs pay-push ungleich",
               signalUriMatchKey("taler://pay-pull/exchange.example.org/7Q4XK2")
                   != signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2"))
        expect("matchKey: anderer Token ungleich",
               signalUriMatchKey("taler://pay-push/exchange.example.org/7Q4XK2")
                   != signalUriMatchKey("taler://pay-push/exchange.example.org/AAAA"))
        expect("matchKey: ohne Scheme -> nil", signalUriMatchKey("pay-push/exchange") == nil)

        // ---- T4: SentRefundStore (Schlüssel-Hash, nie die URI selbst) ----

        // Die Suche nach der eingehenden Zahlung
        // (findIncomingPeerPushCredit, IncomingTransactionLookup.swift) ist
        // hier NICHT abgedeckt: sie ruft preparePeerPushCredit und
        // getTransactionById auf wallet-core auf, das im Selbsttest nicht
        // zur Verfügung steht. Geprüft werden nur die davon unabhängigen
        // Bausteine (Schlüssel-Hash, Zweck-Präfix).

        // 32) Schlüssel: Präfix plus SHA-256-Hex der URI, nie die URI.
        let refundUri = "taler://pay-push/exchange.example.org/7Q4XK2"
        let refundKey = SentRefundStore.storageKey(forOriginalUri: refundUri)
        expect("refund key: Präfix signalLink.sentRefund.",
               refundKey?.hasPrefix("signalLink.sentRefund.") == true)
        expect("refund key: SHA-256 ist 64 Hex-Zeichen",
               (refundKey?.count ?? 0) == "signalLink.sentRefund.".count + 64)
        expect("refund key: URI kommt nicht vor",
               refundKey?.contains("7Q4XK2") != true)
        expect("refund key: SHA-256 Vektor (abc)",
               SentRefundStore.storageKey(forOriginalUri: "abc")
                   == "signalLink.sentRefund.ba7816bf8f01cfea414140de5dae2223"
                      + "b00361a396177a9cb410ff61f20015ad")
        expect("refund key: leere URI -> nil",
               SentRefundStore.storageKey(forOriginalUri: "") == nil)

        // 33) Roundtrip und Überschreiben - eigenes UserDefaults-Suite,
        // damit die Prüfung nicht ins echte UserDefaults der App schreibt.
        let refundSuite = "SignalLinkSelfCheck.SentRefund"
        UserDefaults.standard.removePersistentDomain(forName: refundSuite)
        let refundDefaults = UserDefaults(suiteName: refundSuite)!
        let refundStore = SentRefundStore(defaults: refundDefaults)
        expect("refund: anfangs kein Eintrag",
               refundStore.entry(forOriginalUri: refundUri) == nil)
        let refundSentAt = Date(timeIntervalSince1970: 1_780_000_000)
        refundStore.markSent(originalUri: refundUri,
                             refundTransactionId: "tx:1",
                             at: refundSentAt)
        if let entry = refundStore.entry(forOriginalUri: refundUri) {
            expect("refund: transactionId gelesen", entry.refundTransactionId == "tx:1")
            expect("refund: Zeitpunkt gelesen", entry.sentAt == refundSentAt)
        } else { expect("refund: Eintrag gelesen", false) }
        expect("refund: andere URI ist anderer Schlüssel",
               refundStore.entry(forOriginalUri: refundUri + "?x=1") == nil)
        refundStore.markSent(originalUri: refundUri, refundTransactionId: "tx:2")
        expect("refund: Überschreiben gewinnt (letzter Versand zählt)",
               refundStore.entry(forOriginalUri: refundUri)?.refundTransactionId == "tx:2")
        refundStore.markSent(originalUri: "", refundTransactionId: "tx:3")
        expect("refund: leere URI wird nicht gespeichert",
               refundStore.entry(forOriginalUri: "") == nil)
        UserDefaults.standard.removePersistentDomain(forName: refundSuite)

        // ---- T4: Zweck-Präfix (Refund: <Originalzweck>) ----

        // 34) Präfix genau "Refund: ", Original gefiltert und getrimmt.
        expect("refund Zweck: Präfix Refund: ",
               SignalComposeRefundModel.prefilledSummary(original: "Kaffee") == "Refund: Kaffee")
        expect("refund Zweck: Trim",
               SignalComposeRefundModel.prefilledSummary(original: "  Kaffee \n")
                   == "Refund: Kaffee")
        expect("refund Zweck: nil -> nur Refund",
               SignalComposeRefundModel.prefilledSummary(original: nil) == "Refund")
        expect("refund Zweck: leer -> nur Refund",
               SignalComposeRefundModel.prefilledSummary(original: "   ") == "Refund")
        expect("refund Zweck: Steuerzeichen gefiltert",
               SignalComposeRefundModel.prefilledSummary(original: "Kaf\u{07}fee")
                   == "Refund: Kafee")

        return failed
    }

    /// URL-Literal; die Teststrings sind statisch und streng kodiert.
    private static func u(_ s: String) -> URL {
        URL(string: s)!
    }
}

#endif
