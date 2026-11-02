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
struct SignalContactLine: View {
    private let contact: SignalContact?
    private let avatar: UIImage?

    init(transactionId: String, store: SignalContactStore = .shared) {
        let contact = store.contact(forTransactionId: transactionId)
        self.contact = contact
        self.avatar = contact.flatMap { store.avatar(for: $0) }
    }

    var body: some View {
        if let contact {
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
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(contact.appName ?? "Signal"): \(contact.name ?? "")"))
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
