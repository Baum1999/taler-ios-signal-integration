//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

#if TALER_SIGNAL

/// Herkunftszeile "Signal-Logo, Avatar, Name" für Transaktionsliste und
/// Detailansicht (Android-Gegenstück: TransactionContactLine,
/// android-nachzieh-liste.md N19). Ohne gespeicherten Kontext entsteht keine
/// Zeile - Transaktionen, die nicht über Signal angestoßen wurden, bleiben
/// unverändert.
///
/// Antippen öffnet in Signal die Nachricht zu dieser Zahlung (Link
/// taler-open, link-protokoll.md 12, N20); Signal fragt dabei sofort den
/// aktuellen Status ab. Bei einem Gruppen-Split stehen alle Anteile in
/// `transactionIds`, der Kontakt kommt vom ersten.
struct SignalContactLine: View {
    private let transactionIds: [String]
    private let contact: SignalContact?
    private let avatar: UIImage?

    init(transactionIds: [String], store: SignalContactStore = .shared) {
        self.transactionIds = transactionIds
        let contact = transactionIds.first.flatMap { store.contact(forTransactionId: $0) }
        self.contact = contact
        self.avatar = contact.flatMap { store.avatar(for: $0) }
    }

    init(transactionId: String, store: SignalContactStore = .shared) {
        self.init(transactionIds: [transactionId], store: store)
    }

    var body: some View {
        if let contact {
            let appName = contact.appName ?? "Signal"
            // borderless: in einer List-Zeile (auch als NavigationLink-Label)
            // reagiert nur die Kontaktzeile, der Rest der Zeile öffnet weiter
            // die Details.
            Button {
                ReturnURLBuilder.openPaymentMessage(transactionIds: transactionIds)
            } label: {
                HStack(spacing: 6) {
                    Image("signal_logo")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    avatarView(isGroup: contact.isGroup)
                    if let name = contact.name {
                        Text(name)
                            .talerFont(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Image(systemName: "arrow.up.forward.app")
                        .talerFont(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(appName): \(contact.name ?? "")"))
            .accessibilityHint(Text("Öffnet die Nachricht zu dieser Zahlung in \(appName)."))
        }
    }

    @ViewBuilder
    private func avatarView(isGroup: Bool) -> some View {
        Group {
            if let avatar {
                Image(uiImage: avatar).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.2)
                    Image(systemName: isGroup ? "person.2.fill" : "person.fill")
                        .resizable().scaledToFit()
                        .padding(4)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#endif
