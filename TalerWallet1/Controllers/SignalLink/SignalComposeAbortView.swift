//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

// MARK: - View-Modell

/// Zustand des Sammel-Abbruch-Screens (Paket T5). Abgebrochen wird NUR
/// durch die Bestätigung des Nutzers - Signal fordert nur an, Taler
/// führt keinerlei Aktion vor dem Tap auf "Jetzt abbrechen" aus.
/// Genau ein Rücksprung pro Anfrage (Guard `fired`), mit einem
/// result=<uri>|<status> je Eingangs-URI in Eingangs-Reihenfolge.
/// Verlässt der Nutzer den Screen ohne Entscheidung, gibt es KEINEN
/// Rücksprung (Vertrag Abschnitt 5 Regel 5 - es gibt kein status-Feld,
/// Signal bleibt bei OFFEN). Die URIs werden nie geloggt und nie
/// angezeigt (Inhaberpapier, Eiserne Regel 4).
@MainActor
final class SignalComposeAbortModel: ObservableObject {

    enum Phase: Equatable {
        case loading         // Kaltstart: Backend bereit, URIs werden aufgelöst
        case confirm         // Sammel-Bestätigung
        case working         // Abbrüche laufen
        case finished        // Rücksprung wurde gefeuert
    }

    /// Eine Eingangs-URI samt (soweit ermittelbar) der eigenen
    /// wallet-core-Transaktion. Betrag und Zweck stammen ausschließlich
    /// aus der Transaktion (Eiserne Regel 5), nie aus dem Link.
    struct Entry {
        let uri: String
        var transactionId: String?
        var amountText: String?
        var summaryText: String?
        var majorState: TransactionMajorState?
    }

    let uris: [String]
    let ctx: SignalReturnContext

    @Published var phase: Phase = .loading
    @Published var entries: [Entry] = []
    /// View soll das Sheet schließen.
    @Published var shouldDismiss = false

    private var started = false
    /// Genau ein Rücksprung pro Anfrage (Vertrag Abschnitt 9).
    private var fired = false

    private let wallet = WalletModel.shared

    init(uris: [String], ctx: SignalReturnContext) {
        self.uris = uris
        self.ctx = ctx
    }

    // MARK: Start (Kaltstart)

    func start() async {
        guard !started else { return }
        started = true
        // Kaltstart über den Link: wallet-core evtl. noch nicht initialisiert.
        await SignalLinkBackendGate.awaitBackendReady(Controller.shared)
        var resolved: [Entry] = []
        for uri in uris {
            resolved.append(await resolve(uri: uri))
        }
        entries = resolved
        phase = .confirm
    }

    /// Löst eine URI auf die eigene Transaktion auf: zuerst der eigene
    /// URI-Store (T3, OwnUriStore), dann die Transaktionssuche über alle
    /// Scopes (T2, findOwnPeerTransaction). Wird sie nirgends gefunden,
    /// gehört sie keiner eigenen Transaktion an - sie erhält später
    /// `declined`, es gibt keinen Abbruch-Versuch.
    private func resolve(uri: String) async -> Entry {
        var entry = Entry(uri: uri)
        if let cached = OwnUriStore.shared.transactionId(forUri: uri) {
            entry.transactionId = cached
        } else {
            entry.transactionId = await findOwnPeerTransaction(forTalerUri: uri, model: wallet)
        }
        guard let transactionId = entry.transactionId else { return entry }
        guard let transaction = try? await wallet.getTransactionById(
            transactionId, includeContractTerms: false, viewHandles: true)
        else { return entry }
        entry.majorState = transaction.common.txState.major
        entry.amountText = transaction.common.amountRaw.readableDescription
        if case .peer2peer(let p2p) = transaction,
           let summary = p2p.details.info.summary, !summary.isEmpty {
            entry.summaryText = summary
        }
        return entry
    }

    // MARK: Entscheidung (nur der Nutzer)

    /// Bestätigung: jede zugehörige eigene Transaktion abbrechen und je
    /// Eingangs-URI ein Ergebnis zurückschicken. Ein Abbruch-Fehler
    /// reißt die anderen nicht mit (Android-Spec: pro URI eigenes
    /// Ergebnis statt Fehler des gesamten Vorgangs).
    func confirm() {
        guard phase == .confirm else { return }
        phase = .working
        Task { await runAborts() }
    }

    /// Ablehnung: keine wallet-core-Aktion, alle URIs `declined`
    /// (Vertrag Abschnitt 5 Regel 4).
    func decline() {
        guard phase == .confirm else { return }
        fire(entries.map { (uri: $0.uri, outcome: AbortOutcome.declined) })
    }

    /// Sheet wurde geschlossen (z. B. Swipe) ohne Entscheidung: alle URIs
    /// `declined` (Auftrag Review; Signal bleibt sonst ohne Ergebnis).
    /// Ein neuer Request, der diesen Screen ersetzt, feuert nicht.
    func handleDisappear() {
        guard !fired, phase != .working else { return }
        if let current = SignalLinkRouter.shared.pending,
           current.correlationId != ctx.correlationId { return }
        fire(uris.map { (uri: $0, outcome: AbortOutcome.declined) })
    }

    private func runAborts() async {
        var results: [(uri: String, outcome: String)] = []
        for entry in entries {
            results.append((uri: entry.uri, outcome: await abortOne(entry)))
        }
        fire(results)
    }

    /// Bricht die Transaktion einer URI ab und liefert das Protokoll-
    /// Ergebnis. Schlägt der Abbruch fehl, wird der frische Zustand
    /// geladen (Race: Empfänger hat inzwischen eingelöst, oder die
    /// Transaktion war bereits abgelaufen), bevor gemappt wird.
    private func abortOne(_ entry: Entry) async -> String {
        guard let transactionId = entry.transactionId else {
            return AbortOutcome.outcome(for: nil, abortSucceeded: nil)
        }
        // Bereits abgeschlossen/abgelaufen/abgebrochen: nicht erneut abbrechen,
        // sondern nur mappen (sonst koennte ein No-op-Erfolg "aborted" statt
        // already_claimed/expired liefern).
        switch entry.majorState {
            case .done, .expired, .aborting, .aborted:
                return AbortOutcome.outcome(for: entry.majorState, abortSucceeded: nil)
            default:
                break
        }
        do {
            try await wallet.abortTransaction(transactionId: transactionId)
            return AbortOutcome.outcome(for: entry.majorState, abortSucceeded: true)
        } catch {
            let fresh = try? await wallet.getTransactionById(
                transactionId, includeContractTerms: false, viewHandles: true)
            return AbortOutcome.outcome(
                for: fresh?.common.txState.major ?? entry.majorState,
                abortSucceeded: false)
        }
    }

    /// Feuert den einzigen Rücksprung dieser Anfrage und schließt das
    /// Sheet. Nur über ReturnURLBuilder (Ziel-Validierung, Vertrag 2.5).
    private func fire(_ results: [(uri: String, outcome: String)]) {
        guard !fired else { return }
        fired = true
        phase = .finished
        ReturnURLBuilder.open(ReturnURLBuilder.abortResults(ctx: ctx, results: results))
        SignalLinkRouter.shared.pending = nil
        shouldDismiss = true
    }
}

// MARK: - View

/// Sammel-Bestätigung für talerlink://compose-abort (Paket T5,
/// Android-Gegenstück peer/ComposeAbortScreen.kt): Signal hat beim
/// "Für alle löschen" einer Nachricht die zugehörigen eigenen offenen
/// Zahlungen geschickt. Der Screen löst jede URI auf die eigene
/// Transaktion auf (Betrag/Zweck je Zahlung, soweit ermittelbar),
/// zeigt EINE Bestätigung für alle und bricht nach dem Tap je
/// Transaktion per abortTransaction ab. Der Rücksprung trägt je
/// Eingangs-URI ein result=<uri>|<status>.
struct SignalComposeAbortView: View {

    @StateObject private var vm: SignalComposeAbortModel

    init(uris: [String], ctx: SignalReturnContext) {
        _vm = StateObject(wrappedValue: SignalComposeAbortModel(uris: uris, ctx: ctx))
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        // Während der Abbrüche kein Wegwegschwenken: Teile wären schon
        // abgebrochen, ohne dass Signal ein Ergebnis erhielte.
        .interactiveDismissDisabled(vm.phase == .working)
        .onChange(of: vm.shouldDismiss) { shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .onDisappear { vm.handleDisappear() }
        .task { await vm.start() }
    }

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        vm.uris.count == 1 ? "Zahlung abbrechen?" : "\(vm.uris.count) Zahlungen abbrechen?"
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Wallet wird geladen …")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .confirm:
                confirmView
            case .working:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Die Zahlungen werden abgebrochen …")
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .finished:
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Abgeschlossen.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var confirmView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(vm.entries.indices, id: \.self) { index in
                        entryRow(vm.entries[index])
                    }
                } header: {
                    Text("Bereits angenommene oder abgelaufene Zahlungen können nicht mehr abgebrochen werden.")
                }
            }
            VStack(spacing: 12) {
                Button {
                    vm.confirm()
                } label: {
                    Text("Jetzt abbrechen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    vm.decline()
                } label: {
                    Text("Nicht abbrechen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    /// Zeile je Eingangs-URI: Betrag und Zweck aus der wallet-core-
    /// Transaktion (verifizierte Quelle, Regel 5), nie die URI selbst
    /// (Regel 4). Nicht zugeordnete URIs werden als solche markiert -
    /// sie erhalten `declined`.
    @ViewBuilder
    private func entryRow(_ entry: SignalComposeAbortModel.Entry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let amountText = entry.amountText {
                Text(amountText)
                    .font(.title3)
            } else {
                Text("Betrag unbekannt")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            if let summaryText = entry.summaryText {
                Text(summaryText)
                    .foregroundColor(.secondary)
            }
            if entry.transactionId == nil {
                Text("Zahlung in dieser Wallet nicht gefunden")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#endif
