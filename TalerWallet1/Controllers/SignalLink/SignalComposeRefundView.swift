//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

/// GANA-Code für "unzureichendes Guthaben" (siehe SendAmountView);
/// Initialisierung und talerUri-Polling folgen dem Muster aus
/// SignalComposeSendView (T3), diese Prüfung wird hier erneut gebraucht.
private let signalRefundInsufficientBalanceCode = 7027

/// wallet-core meldet "unzureichendes Guthaben" als GANA-Code 7027, teils
/// als geworfener Fehler statt als Antwort. Duplikat der T3-Hilfsstelle -
/// die dortige ist private und T3-Dateien werden nicht angefasst.
private func signalRefundIsInsufficientBalance(_ error: Error?) -> Bool {
    guard let error else { return false }
    if case WalletBackendError.walletCoreError(let detail) = error,
       detail?.code == signalRefundInsufficientBalanceCode {
        return true
    }
    return false
}

// MARK: - View-Modell

/// Zustand des Refund-Screens. Eine Rückerstattung ist eine NEUE ausgehende
/// Zahlung (peer-push-debit), keine Rückabwicklung der ursprünglichen -
/// deshalb derselbe Ablauf wie T3 (initiatePeerPushDebit, talerUri-Polling,
/// genau ein Rücksprung über ReturnURLBuilder). Betrag und Zweck kommen
/// ausschließlich aus der aufgelösten Original-Transaktion (Eiserne Regel
/// 5), der Deep-Link trägt nur die originalUri als Zuordnung.
@MainActor
final class SignalComposeRefundModel: ObservableObject {

    enum Phase: Equatable {
        case loading         // Kaltstart: Backend + Transaktionssuche
        case alreadySent     // Warnung: für diese URI schon erstattet
        case form            // Formular, Betrag/Zweck vorbefüllt
        case working         // Erstellen / auf talerUri pollen
        case failed          // endgültig, nur noch Rücksprung
    }

    let originalUri: String
    let ctx: SignalReturnContext

    @Published var phase: Phase = .loading
    @Published var amountText = ""
    @Published var summary = ""
    /// Zeitpunkt der bereits gesendeten Erstattung (Phase .alreadySent).
    @Published var alreadySentAt: Date? = nil
    /// Behebbarer Fehler im Formular.
    @Published var errorText: String? = nil
    /// Endgültiger Fehlertext der Phase .failed.
    @Published var failureText: String? = nil
    /// Sichtbarer Arbeitshinweis während .working.
    @Published var workingText: String? = nil
    /// View soll das Sheet schließen.
    @Published var shouldDismiss = false

    /// Original-Betrag (amountEffective der empfangenen Zahlung) - Obergrenze
    /// und Vorbefüllung. Nie aus dem Nachrichtentext (Eiserne Regel 5).
    private var originalAmount: Amount? = nil
    /// Bereinigter Zweck-Text der Original-Transaktion (untrusted Anzeige).
    private var originalSummary: String? = nil
    /// Scope der ausgehenden Erstattung (Währung der Original-Zahlung).
    private var scope: ScopeInfo? = nil

    /// Genau ein Rücksprung pro Vorgang (Vertrag Abschnitt 8, Regel 3).
    private var fired = false
    private var started = false
    private var createTask: Task<Void, Never>? = nil

    private let wallet = WalletModel.shared
    private let controller = Controller.shared

    init(originalUri: String, ctx: SignalReturnContext) {
        self.originalUri = originalUri
        self.ctx = ctx
    }

    // MARK: Vorbefüllung

    /// Zweck-Vorbefüllung: "Refund: <Originalzweck>". Der Originalzweck stammt
    /// aus dem entschlüsselten Contract der Original-Transaktion, ist aber
    /// vom ursprünglichen Sender frei gewählt - also gefiltert (keine
    /// Steuerzeichen) und getrimmt; leer -> nur "Refund". Nonisolated, damit
    /// die Selbstprüfung (SignalLinkSelfCheck) sie ohne MainActor aufrufen
    /// kann - reine String-Verarbeitung ohne Zustand.
    nonisolated static func prefilledSummary(original: String?) -> String {
        let filtered = (original ?? "").filter { !$0.isISOControl }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return filtered.isEmpty ? "Refund" : "Refund: " + filtered
    }

    /// Originalzweck für die Anzeige ("Für: ..."), einzeilig ohne
    /// Steuerzeichen - gleiche Absicherung wie sanitizedHint in T3.
    var sanitizedOriginalSummary: String? {
        guard let summary = originalSummary else { return nil }
        let filtered = summary.filter { !$0.isISOControl }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return filtered.isEmpty ? nil : filtered
    }

    /// Original-Betrag als Anzeige neben dem Eingabefeld (verifizierte
    /// Quelle, Eiserne Regel 5).
    var originalAmountText: String? {
        originalAmount?.readableDescription
    }

    // MARK: Start (Kaltstart)

    func start() async {
        guard !started else { return }
        started = true
        // Kaltstart über den Link: erst wallet-core (Vertrag Abschnitt 3),
        // dann die Original-Transaktion suchen.
        await SignalLinkBackendGate.awaitBackendReady(controller)
        guard let transaction = await findIncomingPeerPushCredit(forTalerUri: originalUri,
                                                                model: wallet),
              case .peer2peer(let p2p) = transaction,
              p2p.common.isDone
        else {
            failureText = "Diese Zahlung wurde in dieser Wallet nicht empfangen."
            phase = .failed
            return
        }

        // Betrag: amountEffective = was tatsächlich angekommen ist. Voll
        // vorbefüllt, nach unten änderbar (Paket-Vorgabe) - nie mehr als
        // der Original-Betrag.
        originalAmount = p2p.common.amountEffective
        amountText = p2p.common.amountEffective.valueStr
        originalSummary = p2p.details.info.summary
        summary = Self.prefilledSummary(original: p2p.details.info.summary)

        // Scope der neuen Zahlung: der der Original-Transaktion (gleiche
        // Währung), sonst erstes passendes Guthaben.
        scope = p2p.common.scopes.first { $0.currency == p2p.common.amountEffective.currencyStr }
        if scope == nil {
            _ = await controller.loadBalances(CallStack().push(), wallet)
            scope = controller.balances
                .filter { $0.disablePeerPayments != true
                       && $0.scopeInfo.currency == p2p.common.amountEffective.currencyStr }
                .first?.scopeInfo
        }
        guard scope != nil else {
            failureText = "Kein für Zahlungen nutzbares Guthaben in dieser Währung vorhanden."
            phase = .failed
            return
        }

        // Dauerhafte Dopplungs-Warnung (SentRefundStore): blockiert das
        // Formular, bis der Nutzer "Verwerfen und neu erstellen" wählt.
        if let entry = SentRefundStore.shared.entry(forOriginalUri: originalUri) {
            alreadySentAt = entry.sentAt
            phase = .alreadySent
        } else {
            phase = .form
        }
    }

    /// "Verwerfen und neu erstellen": Warnung übergehen. Der alte Eintrag
    /// bleibt bestehen, bis die neue Erstattung tatsächlich gesendet wird
    /// (markSent überschreibt ihn dann).
    func overrideWarning() {
        phase = .form
    }

    // MARK: Formular

    /// Parst die Eingabe in ein Amount der Original-Währung.
    func parsedAmount() -> Amount? {
        guard let originalAmount else { return nil }
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Deutsches Dezimalkomma akzeptieren, Taler verlangt Punkt.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return try? Amount(fromString: "\(originalAmount.currencyStr):\(normalized)")
    }

    /// True, wenn die Eingabe über dem Original-Betrag liegt (nur nach
    /// unten änderbar, Paket-Vorgabe).
    var exceedsOriginal: Bool {
        guard let amount = parsedAmount(), let originalAmount else { return false }
        return (try? amount > originalAmount) ?? false
    }

    var canCreate: Bool {
        guard phase == .form, let amount = parsedAmount(),
              !summary.trimmingCharacters(in: .whitespaces).isEmpty
        else { return false }
        return !exceedsOriginal && !amount.isZero
    }

    // MARK: Erstellen

    func create() {
        errorText = nil
        guard let amount = parsedAmount() else {
            errorText = "Bitte einen gültigen Betrag eingeben."
            return
        }
        guard let originalAmount, (try? amount <= originalAmount) == true else {
            errorText = "Der Betrag liegt über dem ursprünglichen Betrag."
            return
        }
        guard !amount.isZero else {
            errorText = "Der Betrag muss größer als null sein."
            return
        }
        let trimmedSummary = summary.trimmingCharacters(in: .whitespaces)
        guard !trimmedSummary.isEmpty else {
            errorText = "Bitte einen Zweck angeben."
            return
        }
        guard let scope else { return }
        workingText = "Die Rückerstattung wird erstellt …"
        phase = .working
        let terms = PeerContractTerms(amount: amount,
                                      summary: trimmedSummary,
                                      purse_expiration: nil,      // defaultExpiration von wallet-core
                                      icon_id: nil)
        createTask = Task {
            await runCreation(scope: scope, terms: terms)
        }
    }

    private func runCreation(scope: ScopeInfo, terms: PeerContractTerms) async {
        do {
            let response = try await wallet.initiatePeerPushDebit(scope: scope,
                                                                  terms: terms,
                                                                  viewHandles: true)
            guard let talerUri = try await pollTalerUri(transactionId: response.transactionId) else {
                // Die Zahlung hat committet, aber keine URI geliefert -
                // sichtbarer Fehler plus cancelled statt Stille (Android:
                // TALER_URI_TIMEOUT_MS-Zweig in ComposeRefundScreen.kt).
                fireCancelled()
                failureText = "Die Zahlungs-URI konnte nicht abgerufen werden. "
                    + "Die Zahlung bleibt in der Taler-Transaktionsliste."
                phase = .failed
                return
            }
            finalizeSuccess(talerUri: talerUri, transactionId: response.transactionId)
        } catch {
            if Task.isCancelled { return }
            // initiatePeerPushDebit gescheitert -> nichts committet,
            // zurück ins Formular (gleiche Regel wie T3 Einzelzahlung).
            phase = .form
            errorText = signalRefundIsInsufficientBalance(error)
                ? "Unzureichendes Guthaben."
                : "Die Zahlung konnte nicht erstellt werden."
        }
    }

    /// Pollt getTransactionById, bis talerUri vorliegt (T3-Muster: alle 2 s,
    /// maximal 10 Minuten - gegen den öffentlichen Demo-Exchange dauerte die
    /// Purse-Erstellung live über 39 s). nil bei Timeout.
    private func pollTalerUri(transactionId: String) async throws -> String? {
        let deadline = Date().addingTimeInterval(SignalComposeSendModel.talerUriTimeout)
        while Date() < deadline {
            if let transaction = try? await wallet.getTransactionById(
                    transactionId, includeContractTerms: false, viewHandles: true),
               case .peer2peer(let p2p) = transaction,
               let uri = p2p.details.talerUri {
                return uri
            }
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(SignalComposeSendModel.pollInterval * 1_000_000_000))
        }
        return nil
    }

    /// Erfolg: eigene URI merken (OwnUriStore, wie T3), Erstattung im
    /// SentRefundStore markieren und genau einmal ready zurückschicken -
    /// talerUri ist die Erstattungs-URI, das JSON hat genau eine URI
    /// (Format wie T3, keine Split-Felder).
    private func finalizeSuccess(talerUri: String, transactionId: String) {
        OwnUriStore.shared.record(uri: talerUri, transactionId: transactionId)
        SentRefundStore.shared.markSent(originalUri: originalUri,
                                        refundTransactionId: transactionId)
        guard !fired else { return }
        fired = true
        let data = SignalLinkPaymentData(uri: [talerUri])
        ReturnURLBuilder.open(ReturnURLBuilder.ready(ctx: ctx,
                                                     talerUri: talerUri,
                                                     paymentDataJson: data.encodedJSON()))
        SignalLinkRouter.shared.pending = nil
        shouldDismiss = true
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
        ReturnURLBuilder.open(ReturnURLBuilder.cancelled(ctx: ctx))
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
           current.correlationId != ctx.correlationId { return }
        fireCancelled()
    }
}

// MARK: - View

/// Refund-Screen für talerlink://compose-refund (Paket T4, Android-
/// Gegenstück link/ComposeRefundScreen.kt): die zur originalUri gehörende,
/// in dieser Wallet EMPFANGENE Zahlung wird aufgelöst, Betrag (voll, nach
/// unten änderbar) und Zweck ("Refund: <Originalzweck>") vorbefüllt, vor
/// einer bereits gesendeten Erstattung gewarnt, und nach Bestätigung eine
/// neue peer-push-debit-Zahlung erzeugt. Bestätigt wird ausschließlich hier
/// durch den Nutzer (Eiserne Regel 1); der Rücksprung zu Signal trägt
/// genau eine neue talerUri plus talerPaymentData.
struct SignalComposeRefundView: View {

    @StateObject private var vm: SignalComposeRefundModel

    init(originalUri: String, ctx: SignalReturnContext) {
        _vm = StateObject(wrappedValue: SignalComposeRefundModel(originalUri: originalUri,
                                                                 ctx: ctx))
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Rückerstattung")
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        // Während des Commit-Fensters kein Swipe-Abbruch: die Purse ist
        // ggf. schon angelegt, ein "cancelled" mitten im Commit würde eine
        // bezahlte Erstattung ohne Signal-Nachricht hinterlassen.
        .interactiveDismissDisabled(vm.phase == .working)
        .onDisappear { vm.handleDisappear() }
        .onChange(of: vm.shouldDismiss) { shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .task { await vm.start() }
    }

    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
            case .loading:
                loadingView
            case .alreadySent:
                alreadySentView
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

    /// Dauerhafte Dopplungs-Warnung: für diese URI wurde bereits eine
    /// Erstattung gesendet. Blockiert das Formular, bis der Nutzer
    /// explizit verwirft und neu erstellt.
    private var alreadySentView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            Text(warningText)
                .multilineTextAlignment(.center)
            Text("Eine Erstattung ist eine neue Zahlung. Sie können die alte Erstattung verwerfen und eine neue erstellen.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    vm.overrideWarning()
                } label: {
                    Text("Verwerfen und neu erstellen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    vm.cancelAndDismiss()
                } label: {
                    Text("Zurück zu Signal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }

    private var warningText: String {
        guard let sentAt = vm.alreadySentAt else {
            return "Für diese Zahlung wurde bereits eine Rückerstattung gesendet."
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Für diese Zahlung wurde bereits am \(formatter.string(from: sentAt)) "
            + "eine Rückerstattung gesendet."
    }

    private var workingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(vm.workingText ?? "Die Rückerstattung wird erstellt …")
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
                if let summary = vm.sanitizedOriginalSummary {
                    Text("Für: \(summary)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack {
                    TextField("Betrag", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                    if let original = vm.originalAmountText {
                        Text(original)
                            .foregroundColor(.secondary)
                    }
                }
                TextField("Zweck", text: $vm.summary)
            }

            Section {
                if vm.exceedsOriginal {
                    Text("Der Betrag liegt über dem ursprünglichen Betrag und kann nur nach unten geändert werden.")
                        .foregroundColor(.red)
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
}

#endif
