//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

/// Swift hat kein Character.isISOControl (anders als Javas/Kotlins
/// Character.isISOControl); Unicode-Kategorie "Control" ist das Aequivalent.
extension Character {
    var isISOControl: Bool {
        unicodeScalars.allSatisfy { $0.properties.generalCategory == .control }
    }
}

/// Fehler im Erstellungs-Ablauf (keine URIs in Meldungen, Regel 4).
enum SignalComposeSendError: Error {
    /// talerUri lag auch nach Ablauf der Frist nicht vor (Android:
    /// TALER_URI_TIMEOUT_MS).
    case uriTimeout
}

/// GANA-Code für "unzureichendes Guthaben" (siehe SendAmountView).
private let signalLinkInsufficientBalanceCode = 7027

/// Fallback-Zweck, falls das Feld leer bleibt (Android: send_peer_default_purpose).
private let signalLinkDefaultSubject = "Gesendet mit GNU Taler"

/// wallet-core meldet "unzureichendes Guthaben" als GANA-Code 7027, teils
/// als geworfener Fehler statt als Antwort.
private func signalLinkIsInsufficientBalance(_ error: Error?) -> Bool {
    guard let error else { return false }
    if case WalletBackendError.walletCoreError(let detail) = error,
       detail?.code == signalLinkInsufficientBalanceCode {
        return true
    }
    return false
}

/// Ergebnis eines Purse-Versuchs. Fehler werden als Merker getragen, nie
/// als Error-Objekt (Sendable für die TaskGroup) und nie mit URI-Inhalt
/// (Regel 4).
struct SignalLinkShareResult: Sendable {
    let index: Int
    var transactionId: String?
    var talerUri: String?
    var failed: Bool = false
    var insufficientBalance: Bool = false
}

/// Eine Purse anlegen; Fehler werden als Ergebnis getragen, nie geworfen,
/// damit ein Anteil die anderen nicht mitreißt. Läuft außerhalb des
/// Main-Actors (wallet-core-Aufrufe sind nonisolated).
private func signalLinkInitiateShare(wallet: WalletModel,
                                     index: Int,
                                     direction: SignalLinkDirection,
                                     scope: ScopeInfo,
                                     terms: PeerContractTerms,
                                     pullExchangeBaseUrl: String?) async -> SignalLinkShareResult {
    do {
        if direction == .payPush {
            let response = try await wallet.initiatePeerPushDebit(scope: scope, terms: terms, viewHandles: true)
            return SignalLinkShareResult(index: index,
                                          transactionId: response.transactionId,
                                          talerUri: nil)
        } else {
            let response = try await wallet.initiatePeerPullCredit(pullExchangeBaseUrl, terms: terms, viewHandles: true)
            return SignalLinkShareResult(index: index,
                                          transactionId: response.transactionId,
                                          talerUri: response.talerUri)
        }
    } catch {
        return SignalLinkShareResult(index: index,
                                      transactionId: nil,
                                      talerUri: nil,
                                      failed: true,
                                      insufficientBalance: signalLinkIsInsufficientBalance(error))
    }
}

/// N Purses parallel (Paket-Vorgabe; TaskGroup ohne Throw, weil ein
/// Teilfehler zur Fehlermeldung führt, nicht zum Abbruch der anderen).
private func signalLinkInitiateSharesParallel(wallet: WalletModel,
                                              count: Int,
                                              direction: SignalLinkDirection,
                                              scope: ScopeInfo,
                                              terms: PeerContractTerms,
                                              pullExchangeBaseUrl: String?) async -> [SignalLinkShareResult] {
    var results: [SignalLinkShareResult] = []
    await withTaskGroup(of: SignalLinkShareResult.self) { group in
        for index in 0..<count {
            group.addTask {
                await signalLinkInitiateShare(wallet: wallet,
                                              index: index,
                                              direction: direction,
                                              scope: scope,
                                              terms: terms,
                                              pullExchangeBaseUrl: pullExchangeBaseUrl)
            }
        }
        for await result in group {
            results.append(result)
        }
    }
    return results.sorted { $0.index < $1.index }
}

// MARK: - View-Modell

/// Zustand des Compose-Screens. Geld bewegt ausschließlich wallet-core
/// (initiatePeerPushDebit / initiatePeerPullCredit), ausgelöst durch den
/// Tap auf "Erstellen" - Signal erhält nur die erzeugten URIs über den
/// Rücksprung (ReturnURLBuilder, nie direkt UIApplication.open auf eine
/// fremde URL). Genau ein Rücksprung pro Vorgang (Guard `fired`).
@MainActor
final class SignalComposeSendModel: ObservableObject {

    enum Phase: Equatable {
        case loading         // Kaltstart: Backend/Salden werden geladen
        case form            // Eingabeformular
        case working         // Purses werden erstellt / auf talerUri gepollt
        case failed          // endgültiger Fehler, nur noch Rücksprung möglich
    }

    /// Warten auf talerUri je Vorgang: 10 Minuten (Android
    /// ComposeSendScreen.kt TALER_URI_TIMEOUT_MS - gegen den öffentlichen
    /// Demo-Exchange dauerte allein die Purse-Erstellung live über 39 s).
    static let talerUriTimeout: TimeInterval = 600
    /// Poll-Intervall auf talerUri (Paket-Vorgabe: alle 2 s).
    static let pollInterval: TimeInterval = 2
    /// Backoff für serialisierte Wiederholungen nach "unzureichendes
    /// Guthaben": 1 s vor dem 2. Versuch, 2 s vor dem 3. Versuch (4 s wäre
    /// der Backoff vor einem weiteren Versuch, der nach der Vorgabe "bis
    /// 3 Versuche pro Purse" nicht mehr stattfindet).
    static let retryBackoffs: [TimeInterval] = [1, 2, 4]

    let params: ComposeSendParams

    @Published var phase: Phase = .loading
    @Published var direction: SignalLinkDirection
    /// Volle Balance-Objekte (nicht nur ScopeInfo), damit .available fürs
    /// Guthaben-Anzeigen je Scope zur Verfügung steht.
    @Published var balances: [Balance] = []
    @Published var scopes: [ScopeInfo] = []
    @Published var scopeIndex: Int = 0
    @Published var amountText = ""
    @Published var summary = ""
    @Published var splitEnabled = false
    @Published var personCount: Int = 2
    @Published var includeSelf = true
    /// Gebühren-Vorschau aus amountEffective (was tatsächlich ankommt),
    /// nie amountRaw (Android 87aab58a).
    @Published var effectiveText: String? = nil
    @Published var insufficientBalance = false
    /// Behebbarer Fehler im Formular.
    @Published var errorText: String? = nil
    /// Endgültiger Fehlertext der Phase .failed.
    @Published var failureText: String? = nil
    /// Sichtbarer Arbeitshinweis während .working.
    @Published var workingText: String? = nil
    /// View soll das Sheet schließen.
    @Published var shouldDismiss = false

    /// Genau ein Rücksprung pro Vorgang (Vertrag Abschnitt 8, Regel 3).
    private var fired = false
    private var started = false
    private var createTask: Task<Void, Never>? = nil
    /// Exchange-URL der letzten checkPeerPullCredit-Antwort (für
    /// initiatePeerPullCredit; nil = wallet-core entscheidet selbst).
    private var lastPullExchangeBaseUrl: String? = nil

    private let wallet = WalletModel.shared
    private let controller = Controller.shared

    init(params: ComposeSendParams) {
        self.params = params
        self.direction = params.direction
        if params.isGroup {
            // Empfänger ohne Absender, vorbelegt aus memberCount (nur
            // Anzeigehilfe - untrusted, Vertrag 2.6), begrenzt auf 2...10.
            self.personCount = min(10, max(2, params.memberCount - 1))
        }
        self.summary = Self.subjectPrefill(senderAppName: params.senderAppName,
                                           recipientHint: Self.sanitize(params.recipientHint))
    }

    /// senderAppName ist wie recipientHint angreiferkontrolliert (Vertrag
    /// 2.6): Steuerzeichen raus, leer -> nil. Gleiche Regel wie sanitizedHint
    /// unten, hier als static, weil init() noch kein self hat.
    private static func sanitize(_ value: String?) -> String? {
        guard let value else { return nil }
        let filtered = value.filter { !$0.isISOControl }
        let trimmed = filtered.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Vorschlagstext fuers Zweck-Feld ("send via Signal" bzw. "send via
    /// Signal: Alice") - nur gesetzt, wenn der Absender einen App-Namen
    /// mitgegeben hat (aeltere Signal-Builds oder andere Aufrufer ohne
    /// diesen Parameter aendern das Formular nicht). Bleibt wie jede andere
    /// Vorbefuellung frei editierbar.
    private static func subjectPrefill(senderAppName: String?, recipientHint: String?) -> String {
        guard let appName = sanitize(senderAppName) else { return "" }
        if let hint = recipientHint {
            return "send via \(appName): \(hint)"
        }
        return "send via \(appName)"
    }

    // MARK: Start (Kaltstart)

    func start() async {
        guard !started else { return }
        started = true
        // Kaltstart über den Link: erst wallet-core bereit, dann Salden
        // (Vertrag Abschnitt 3: "backendState == .ready abwarten").
        await SignalLinkBackendGate.awaitBackendReady(controller)
        _ = await controller.loadBalances(CallStack().push(), wallet)
        balances = controller.balances
            .filter { $0.disablePeerPayments != true }
        scopes = balances.map { $0.scopeInfo }
        guard !scopes.isEmpty else {
            failureText = "Kein für Zahlungen nutzbares Guthaben vorhanden."
            phase = .failed
            return
        }
        scopeIndex = 0
        phase = .form
    }

    // MARK: Formular

    var selectedScope: ScopeInfo? {
        guard scopes.indices.contains(scopeIndex) else { return scopes.first }
        return scopes[scopeIndex]
    }

    var selectedBalance: Balance? {
        guard balances.indices.contains(scopeIndex) else { return balances.first }
        return balances[scopeIndex]
    }

    /// Beschriftung je Scope im Auswahl-Picker: Währung plus Exchange-Host,
    /// falls vorhanden (Android-Gegenstück: "%1$s via %2$s").
    func scopeLabel(_ scope: ScopeInfo) -> String {
        guard let host = scope.url?.trimURL else { return scope.currency }
        return "\(scope.currency) via \(host)"
    }

    /// Split-Regelung gilt nur für Gruppe + Senden (Paket-Vorgabe).
    var showSplitControls: Bool {
        params.isGroup && direction == .payPush
    }

    /// recipientHint ist angreiferkontrolliert: nur einzeilig, ohne
    /// Steuerzeichen anzeigen (Vertrag 2.6).
    var sanitizedHint: String? { Self.sanitize(params.recipientHint) }

    /// Parst die Eingabe in ein Amount der gewählten Währung. Beträge
    /// kommen nie aus dem Link (Signal schickt keine).
    func parsedAmount() -> Amount? {
        guard let scope = selectedScope else { return nil }
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Deutsches Dezimalkomma akzeptieren, Taler verlangt Punkt.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return try? Amount(fromString: "\(scope.currency):\(normalized)")
    }

    /// Anteil pro Person beim Split (FLOOR auf 8 Stellen, siehe AmountSplit).
    var shareAmount: Amount? {
        guard splitEnabled, let total = parsedAmount(),
              let totalDecimal = Self.decimal(from: total),
              let shareDecimal = AmountSplit.splitAmountEvenly(
                  total: totalDecimal,
                  parts: personCount + (includeSelf ? 1 : 0))
        else { return nil }
        return Self.amount(from: shareDecimal, currency: total.currencyStr)
    }

    var canCreate: Bool {
        guard phase == .form else { return false }
        return parsedAmount() != nil
    }

    /// Schlüssel der Gebühren-Vorschau: ändert sich eine Eingabe, bricht
    /// SwiftUI die alte .task(id:) ab und startet neu.
    var feePreviewKey: String {
        "\(amountText)|\(direction.rawValue)|\(scopeIndex)"
    }

    /// Gebühren-Vorschau (nur Anzeige). Beträge aus der Antwort von
    /// wallet-core, nie aus dem Nachrichtentext (Eiserne Regel 5).
    func refreshFeePreview() async {
        guard phase == .form else { return }
        effectiveText = nil
        insufficientBalance = false
        guard let amount = parsedAmount(), let scope = selectedScope else { return }
        // Entprellung: Eingaben während der Laufzeit brechen die Task ab.
        try? await Task.sleep(nanoseconds: 400_000_000)
        if Task.isCancelled { return }
        do {
            if direction == .payPush {
                let response = try await wallet.checkPeerPushDebit(amount, scope: scope, viewHandles: true)
                if response.type == "insufficient-balance" {
                    insufficientBalance = true
                } else if let effective = response.amountEffective {
                    effectiveText = "Empfänger erhält: \(effective.readableDescription)"
                }
            } else {
                let response = try await wallet.checkPeerPullCredit(amount, scope: scope, viewHandles: true)
                lastPullExchangeBaseUrl = response.exchangeBaseUrl
                effectiveText = "Du erhältst: \(response.amountEffective.readableDescription)"
            }
        } catch {
            // wallet-core meldet "unzureichendes Guthaben" teils als
            // Fehlercode 7027 statt als Antwort (siehe SendAmountView).
            if signalLinkIsInsufficientBalance(error) {
                insufficientBalance = true
            }
        }
    }

    // MARK: Erstellen

    func create() {
        errorText = nil
        guard let total = parsedAmount() else {
            errorText = "Bitte einen gültigen Betrag eingeben."
            return
        }
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)
        let resolvedSummary = trimmedSummary.isEmpty ? signalLinkDefaultSubject : trimmedSummary
        guard let scope = selectedScope else { return }
        let isSplit = showSplitControls && splitEnabled
        let count = isSplit ? personCount : 1
        var perShare = total
        if isSplit {
            guard let totalDecimal = Self.decimal(from: total),
                  let shareDecimal = AmountSplit.splitAmountEvenly(
                      total: totalDecimal,
                      parts: count + (includeSelf ? 1 : 0)),
                  let share = Self.amount(from: shareDecimal, currency: total.currencyStr),
                  !share.isZero
            else {
                errorText = "Der Betrag ist zu klein für diese Aufteilung."
                return
            }
            perShare = share
        }
        workingText = isSplit
            ? "Die Zahlung wird auf \(count) Anteile aufgeteilt …"
            : "Die Zahlung wird erstellt …"
        phase = .working
        let terms = PeerContractTerms(amount: perShare,
                                      summary: resolvedSummary,
                                      purse_expiration: nil,      // defaultExpiration von wallet-core
                                      icon_id: nil)
        createTask = Task {
            await runCreation(scope: scope, terms: terms, total: total, isSplit: isSplit, count: count)
        }
    }

    private func runCreation(scope: ScopeInfo,
                             terms: PeerContractTerms,
                             total: Amount,
                             isSplit: Bool,
                             count: Int) async {
        let pullBase = direction == .payPull ? (lastPullExchangeBaseUrl ?? scope.url) : nil

        // Phase A: N Purses parallel anlegen (Split) bzw. eine (Einzelzahlung).
        var results = await signalLinkInitiateSharesParallel(wallet: wallet,
                                                            count: count,
                                                            direction: direction,
                                                            scope: scope,
                                                            terms: terms,
                                                            pullExchangeBaseUrl: pullBase)

        // Phase B: "unzureichendes Guthaben" -> serialisiert mit Backoff
        // erneut, maximal 3 Versuche pro Purse (kein Teilversand: andere
        // Fehler werden nie wiederholt).
        var attempts = 1
        while attempts < 3 {
            let retryable = results.filter { $0.failed && $0.insufficientBalance }
            if retryable.isEmpty { break }
            if attempts - 1 < Self.retryBackoffs.count {
                let backoff = Self.retryBackoffs[attempts - 1]
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
            if Task.isCancelled { break }
            attempts += 1
            for share in retryable {
                results[share.index] = await signalLinkInitiateShare(wallet: wallet,
                                                                     index: share.index,
                                                                     direction: direction,
                                                                     scope: scope,
                                                                     terms: terms,
                                                                     pullExchangeBaseUrl: pullBase)
            }
        }

        // Endgültiger Initiate-Fehler?
        if results.contains(where: { $0.failed }) {
            if count == 1 {
                // Einzelzahlung: nichts committet -> zurück ins Formular.
                phase = .form
                errorText = results[0].insufficientBalance
                    ? "Unzureichendes Guthaben."
                    : "Die Zahlung konnte nicht erstellt werden."
                return
            }
            // Split: kein Teilversand - keine ready-Rückmeldung. Die
            // bereits erzeugten Transaktionen bleiben in der
            // Taler-Transaktionsliste (Nutzer kann sie dort abbrechen).
            enterPartialFailure(failed: results.filter { $0.failed }.count, of: count)
            return
        }

        // Phase C: pro Transaktion auf talerUri pollen (2 s, 10 min).
        do {
            let uris = try await pollTalerUris(results: results)
            finalizeSuccess(uris: uris,
                            transactionIds: results.map { $0.transactionId ?? "" },
                            total: total,
                            isSplit: isSplit)
        } catch {
            if count == 1 {
                // Die Zahlung hat committet, aber keine URI geliefert -
                // sichtbarer Fehler plus cancelled statt Stille
                // (Android-Verhalten beim TALER_URI_TIMEOUT_MS).
                fireCancelled()
                failureText = "Die Zahlungs-URI konnte nicht abgerufen werden. Die Zahlung bleibt in der Taler-Transaktionsliste."
                phase = .failed
            } else {
                enterPartialFailure(failed: 1, of: count)
            }
        }
    }

    /// Pollt je Transaktion getTransactionById, bis talerUri vorliegt.
    /// Vorab bekannte URIs (peer-pull liefert sie direkt in der Antwort)
    /// werden nicht erneut abgefragt.
    private func pollTalerUris(results: [SignalLinkShareResult]) async throws -> [String] {
        var uris: [String?] = results.map { $0.talerUri }
        let deadline = Date().addingTimeInterval(Self.talerUriTimeout)
        while Date() < deadline {
            for index in results.indices where uris[index] == nil {
                guard let transactionId = results[index].transactionId else { continue }
                if let transaction = try? await wallet.getTransactionById(
                    transactionId, includeContractTerms: false, viewHandles: true),
                   case .peer2peer(let p2p) = transaction,
                   let uri = p2p.details.talerUri {
                    uris[index] = uri
                }
            }
            if !uris.contains(where: { $0 == nil }) {
                return uris.map { $0 ?? "" }
            }
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
        }
        throw SignalComposeSendError.uriTimeout
    }

    /// Erfolg: URIs merken (OwnUriStore, T5) und genau einmal ready
    /// zurückschicken - talerUri ist die erste URI, das JSON alle.
    /// includeSelf und totalAmount nur beim Split (Paket-Vorgabe).
    private func finalizeSuccess(uris: [String],
                                 transactionIds: [String],
                                 total: Amount,
                                 isSplit: Bool) {
        let groupId = isSplit ? params.ctx.correlationId : nil
        for (uri, transactionId) in zip(uris, transactionIds) {
            OwnUriStore.shared.record(uri: uri, transactionId: transactionId, groupId: groupId)
        }
        guard !fired, let first = uris.first else { return }
        fired = true
        let data = SignalLinkPaymentData(
            includeSelf: isSplit ? includeSelf : nil,
            totalAmount: isSplit ? total.valueStr : nil,
            uri: uris)
        ReturnURLBuilder.open(ReturnURLBuilder.ready(ctx: params.ctx,
                                                     talerUri: first,
                                                     paymentDataJson: data.encodedJSON()))
        SignalLinkRouter.shared.pending = nil
        shouldDismiss = true
    }

    /// Endgültiger Teil-Fehler beim Split (Regel: kein Teilversand).
    private func enterPartialFailure(failed: Int, of total: Int) {
        failureText = "\(failed) von \(total) Anteilen konnten nicht erstellt werden. "
            + "Es wurde nichts an Signal gesendet. Bereits erstellte Zahlungen bleiben "
            + "in der Taler-Transaktionsliste und können dort abgebrochen werden."
        phase = .failed
    }

    // MARK: Abbrechen / Rücksprung

    /// Abbrechen-Knopf: cancelled zurückschicken und Sheet schließen.
    func cancelAndDismiss() {
        createTask?.cancel()
        fireCancelled()
        shouldDismiss = true
    }

    private func fireCancelled() {
        guard !fired else { return }
        fired = true
        ReturnURLBuilder.open(ReturnURLBuilder.cancelled(ctx: params.ctx))
        SignalLinkRouter.shared.pending = nil
    }

    /// Sheet wurde geschlossen: ohne Ergebnis cancelled feuern - außer ein
    /// neuer compose-*-Request hat diesen Screen ersetzt (Vertrag
    /// Abschnitt 3: älterer Screen wird ersetzt, ohne zu feuern).
    func handleDisappear() {
        createTask?.cancel()
        guard !fired else { return }
        // Nach Swipe-Schließen ist pending bereits nil (-> cancelled feuern);
        // nur ein ANDERER, neuer Request ersetzt diesen Screen ohne Rücksprung.
        if let current = SignalLinkRouter.shared.pending,
           current.correlationId != params.ctx.correlationId { return }
        fireCancelled()
    }

    // MARK: Hilfsstellen

    /// Amount -> Decimal, exakt aus den Ganzzahl-Feldern (fraction hat
    /// Basis 10^8, Amounts aus dem Formular sind normalisiert) - dasselbe
    /// Muster wie TalerPOS/Model/Amount.swift.
    static func decimal(from amount: Amount) -> Decimal? {
        let value = Decimal(amount.integer) + Decimal(amount.fraction) / Decimal(100_000_000)
        return value
    }

    /// Decimal -> Amount; nil, wenn kein gültiger Taler-Betrag (mehr als 8
    /// Nachkommastellen kann es nach dem FLOOR nicht geben). Die
    /// String-Darstellung von Decimal ist ein schlichter Dezimalstring.
    static func amount(from decimal: Decimal, currency: String) -> Amount? {
        try? Amount(fromString: "\(currency):\(decimal)")
    }
}

// MARK: - View

/// Compose-Screen für talerlink://compose-send (Paket T3, Android-Gegenstück
/// link/ComposeSendScreen.kt): Zahlung (Senden = peer-push-debit) oder
/// Anforderung (Anfordern = peer-pull-credit) erstellen, bei Gruppen
/// optional als Split, dann mit den erzeugten URIs zu Signal zurückspringen
/// (Signal verschickt die Nachricht; Taler bewegt das Geld nur nach dem
/// Tap auf "Erstellen", nie automatisch).
struct SignalComposeSendView: View {

    @StateObject private var vm: SignalComposeSendModel

    init(params: ComposeSendParams) {
        _vm = StateObject(wrappedValue: SignalComposeSendModel(params: params))
    }

    private var title: String {
        if let hint = vm.sanitizedHint {
            return "Zahlung für \(hint)"
        }
        return "Zahlung"
    }

    /// Visuelle Titel-Darstellung: Empfängername fett abgesetzt vom
    /// statischen "Zahlung für"-Praefix - unabhaengig davon, ob der
    /// Empfaenger eine Gruppe oder ein 1:1-Kontakt ist. navigationTitle
    /// selbst (s.u.) bleibt als Klartext-String erhalten, da iOS ihn fuer
    /// das Back-Button-Label des naechsten Screens sowie Accessibility
    /// braucht; dieses principal-Toolbar-Item ueberschreibt nur die
    /// Anzeige in der Navigationsleiste.
    ///
    /// TODO Avatar: kein Avatar-Bildchen vor dem Titel, solange
    /// ComposeSendParams kein Avatar-Feld hat (s. SignalLinkRequest.swift) -
    /// kommt wenn Apple Developer Program.
    @ViewBuilder
    private var titleView: some View {
        if let hint = vm.sanitizedHint {
            (Text("Zahlung für ") + Text(hint).fontWeight(.bold))
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text("Zahlung").font(.headline)
        }
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) { titleView }
                }
        }
        .navigationViewStyle(.stack)
        // Während des Commit-Fensters kein Swipe-Abbruch: die Purses sind
        // ggf. schon angelegt, ein "cancelled" mitten im Commit würde eine
        // bezahlte Zahlung ohne Signal-Nachricht hinterlassen.
        .interactiveDismissDisabled(vm.phase == .working)
        .onDisappear { vm.handleDisappear() }
        .onChange(of: vm.shouldDismiss) { shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .task { await vm.start() }
        .task(id: vm.feePreviewKey) { await vm.refreshFeePreview() }
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
            case .loading:
                loadingView
            case .form:
                formView
            case .working:
                workingView
            case .failed:
                failedView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Wallet wird geladen …")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(vm.workingText ?? "Die Zahlung wird erstellt …")
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(vm.failureText ?? "Es ist ein Fehler aufgetreten.")
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                vm.cancelAndDismiss()
            } label: {
                Text("Zurück zu Signal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private var formView: some View {
        Form {
            Section {
                Picker("", selection: $vm.direction) {
                    Text("Senden").tag(SignalLinkDirection.payPush)
                    Text("Anfordern").tag(SignalLinkDirection.payPull)
                }
                .pickerStyle(.segmented)

                HStack {
                    TextField("Betrag", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                    if vm.scopes.count > 1 {
                        Picker("", selection: $vm.scopeIndex) {
                            ForEach(vm.scopes.indices, id: \.self) { index in
                                Text(vm.scopeLabel(vm.scopes[index])).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                    } else if let scope = vm.selectedScope {
                        Text(scope.currency).foregroundColor(.secondary)
                    }
                }
                if let balance = vm.selectedBalance {
                    Text("Verfügbar: \(balance.available.readableDescription)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                TextField("Zweck", text: $vm.summary)
            }

            if vm.params.isGroup {
                Section {
                    if vm.params.memberCount > 0 {
                        Text("Gruppe mit \(vm.params.memberCount) Mitgliedern")
                    }
                    if vm.showSplitControls {
                        splitSection
                    }
                }
            }

            if vm.params.disappearingMessagesSeconds > 0 {
                Section {
                    Text("Chatnachrichten in diesem Chat verschwinden automatisch. Die Zahlung bleibt davon unberührt.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                if vm.insufficientBalance {
                    Text("Unzureichendes Guthaben für diesen Betrag.")
                        .foregroundColor(.red)
                } else if let effective = vm.effectiveText {
                    Text(effective)
                        .foregroundColor(.secondary)
                }
                if let error = vm.errorText {
                    Text(error).foregroundColor(.red)
                }
                Button {
                    vm.create()
                } label: {
                    Text("Erstellen")
                }
                .disabled(!vm.canCreate)
                Button("Abbrechen") {
                    vm.cancelAndDismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var splitSection: some View {
        Toggle("Aufteilen", isOn: $vm.splitEnabled)
        if vm.splitEnabled {
            Stepper("Personen: \(vm.personCount)", value: $vm.personCount, in: 2...10)
            Toggle("Mich mitzählen", isOn: $vm.includeSelf)
            if let share = vm.shareAmount {
                Text("Anteil pro Person: \(share.readableDescription)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#endif
