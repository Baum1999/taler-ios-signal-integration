//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

/// Inhalt des Sheets: die beim Einfügen gefundenen URIs.
struct MultiPaste: Identifiable {
    let id = UUID()
    let uris: [URL]
}

/// Anteile gefunden (Einfügen mit mehreren taler://-URIs). Zeigt, was noch
/// offen ist, und lässt den Nutzer genau einen Anteil öffnen (Android:
/// MultiUriSummaryDialog in ScanQrScreen.kt). Annehmen passiert erst im
/// normalen Annehmen-Sheet nach dem Tap, nie hier.
struct MultiUriSummaryView: View {
    let uris: [URL]
    let onChoose: (URL) -> Void

    @EnvironmentObject private var model: WalletModel
    @Environment(\.dismiss) private var dismiss
    @State private var aggregate: MultiUriAggregate?

    var body: some View {
        NavigationView {
            content
                .navigationTitle(aggregate.map { "\($0.total) Anteile gefunden" } ?? "Anteile werden geprüft …")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let aggregate {
            List {
                Section {
                    if let total = aggregate.totalAmount {
                        Text("Gesamt (offen + von dir angenommen): \(total.readableDescription)")
                    }
                    if aggregate.unavailable > 0 {
                        Text("\(aggregate.unavailable) von \(aggregate.total) nicht mehr verfügbar (angenommen, abgebrochen oder abgelaufen)")
                    }
                    Text(aggregate.acceptedByMe > 0
                         ? "Du hast \(aggregate.acceptedByMe) davon bereits angenommen."
                         : "Du hast noch keinen davon angenommen.")
                    if aggregate.acceptedByMe > 0 {
                        Label("Du hast über diese Einfügung bereits einen Anteil angenommen. Einen zweiten anzunehmen ist wahrscheinlich nicht beabsichtigt.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
                if !aggregate.open.isEmpty {
                    Section {
                        ForEach(aggregate.open) { share in
                            Button(MultiUriSummary.label(for: share)) {
                                guard let url = URL(string: share.uri) else { return }
                                onChoose(url)
                            }
                        }
                    }
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func load() async {
        let strings = uris.map(\.absoluteString)
        aggregate = await MultiUriSummary.build(
            uris: strings,
            isOwn: { OwnUriStore.shared.transactionId(forUri: $0) != nil },
            preview: { uri in
                guard let prepared = try? await model.preparePeerPushCredit(uri) else {
                    return SharePreview(state: .unavailable)
                }
                let state: ShareState
                switch prepared.txState.major {
                    case .dialog: state = .open
                    case .done: state = .acceptedByMe
                    default: state = .unavailable
                }
                return SharePreview(state: state, amount: prepared.amountRaw,
                                    exchangeBaseUrl: prepared.exchangeBaseUrl)
            })
    }
}

#endif
