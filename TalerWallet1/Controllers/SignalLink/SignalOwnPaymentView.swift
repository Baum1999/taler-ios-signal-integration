//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

/// Die eigene, per talerlink://pay-* angesprochene Zahlung (transactionId
/// plus die bereinigte taler://-URI für den Rücksprung). Identifiziert über
/// die transactionId - dieselbe Zahlung kann nicht zweimal ein Sheet öffnen.
struct SignalOwnPaymentInfo: Identifiable {
    let transactionId: String
    let talerUri: URL
    var id: String { transactionId }
}

/// Zeigt die eigene, ausgehende Zahlung (Geld senden oder Zahlung anfordern)
/// mit der Möglichkeit, sie abzubrechen - Signal-Aktion "Abbrechen" einer
/// eigenen offenen Zahlung (Vertrag Abschnitt 6). Abgebrochen wird NUR durch
/// Nutzeraktion (Knopf plus Bestätigungsdialog), nie automatisch.
/// Nach erfolgreichem Abbruch Rücksprung ready zu Signal, beim Schließen ohne
/// Abbruch cancelled (via Sheet-onDismiss beim Router) - jeweils genau einmal,
/// der Kontext wird beim ersten Rücksprung verbraucht.
/// Die URI wird nie angezeigt und nie geloggt (Inhaberpapier, Vertrag 2.6).
struct SignalOwnPaymentView: View {
    /// Die eigene Zahlung samt taler://-URI für den Rücksprung.
    let info: SignalOwnPaymentInfo

    @EnvironmentObject private var model: WalletModel
    @Environment(\.dismiss) private var dismiss

    @State private var transaction: TalerTransaction? = nil
    @State private var loadFailed = false
    @State private var askingAbort = false
    @State private var aborting = false

    /// Lädt die Transaktion - beim Kaltstart über den Link wartet wallet-core
    /// evtl. noch auf Init, deshalb zuerst awaitBackendReady (T1).
    @MainActor
    private func loadTransaction() async {
        await SignalLinkBackendGate.awaitBackendReady(Controller.shared)
        transaction = try? await model.getTransactionById(info.transactionId,
                                                    includeContractTerms: true)
        if transaction == nil { loadFailed = true }
    }

    /// Abbruch der Zahlung - NUR über den Bestätigungsdialog erreichbar.
    /// Bei Erfolg ready zur Signal und schließen, bei Fehler bleibt der
    /// Rücksprung offen (Nutzer kann es erneut versuchen oder schließen ->
    /// dann cancelled).
    @MainActor
    private func abortConfirmed() {
        guard !aborting else { return }
        aborting = true
        Task {
            do {
                try await model.abortTransaction(transactionId: info.transactionId)
                signalReturnReady(for: info.talerUri)
                dismiss()
            } catch {
                aborting = false
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            if let transaction, case .peer2peer(let p2p) = transaction {
                let common = p2p.common
                Text("Your Payment", comment: "Nav Title, own pending payment")
                    .talerFont(.title)
                List {
                    Section {
                        Text(common.amountRaw.readableDescription)
                            .talerFont(.title)
                        if let summary = p2p.details.info.summary, !summary.isEmpty {
                            Text(summary)
                                .talerFont(.body)
                        }
                        HStack {
                            Text("Status", comment: "transaction status heading")
                                .talerFont(.body)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(common.txState.major.localizedState)
                                .talerFont(.body)
                        }
                    }
                }
                if common.isAbortable {
                    Button {
                        askingAbort = true
                    } label: {
                        Text("Abort Payment", comment: "abort own pending payment")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .disabled(aborting)
                } else {
                    // nicht mehr abbrechbar (z. B. schon abgeschlossen)
                    Text(common.localizedTypePast(common.type))
                        .talerFont(.body)
                        .foregroundColor(.secondary)
                }
            } else if loadFailed {
                Text("Transaction not found",
                     comment: "error message for missing transaction")
                    .talerFont(.title3)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                Text("Loading...", comment: "loading message")
                    .talerFont(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done", comment: "close button")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TalerButtonStyle(type: .bordered))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .confirmationDialog(String(localized: "Are you sure you want to abort this transaction?"),
                            isPresented: $askingAbort, titleVisibility: .visible) {
            Button(String(localized: "Abort Payment", comment: "abort own pending payment"),
                   role: .destructive) {
                abortConfirmed()
            }
            Button(String(localized: "Cancel", comment: "dialog button"),
                   role: .cancel) { }
        }
        .task { await loadTransaction() }
    }
}

#endif
