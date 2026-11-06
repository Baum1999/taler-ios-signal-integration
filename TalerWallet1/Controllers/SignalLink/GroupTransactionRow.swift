//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI
import taler_swift

#if TALER_SIGNAL

extension TransactionListEntry where T == TalerTransaction {
    /// Stabile ForEach-Identität: transactionId bzw. "group_<groupId>".
    var listId: String {
        switch self {
            case .single(let tx): return tx.id
            case .group(let groupId, _, _): return "group_\(groupId)"
        }
    }
}

/// Sammelzeile für einen Gruppen-Split: sieht aus wie eine einzelne
/// Transaktion (TransactionRowView) und zeigt alles, was für alle Anteile
/// gleich ist. Antippen führt zur Liste der Anteile, dort bleibt jeder Anteil
/// eine ganz normale Zeile - Detailansicht, Abbrechen und Löschen funktionieren
/// wie bei Einzeltransaktionen.
struct GroupTransactionRow<Row: View>: View {
    let groupId: String
    let shares: [TalerTransaction]
    let includeSelf: Bool?
    let scope: ScopeInfo
    @ViewBuilder let row: (TalerTransaction) -> Row

    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var body: some View {
        NavigationLink {
            List {
                ForEach(shares, id: \.self) { tx in
                    row(tx)
                }
            }
            .listStyle(myListStyle.style).anyView
            .background(FullBackground())
            .navigationTitle(String(localized: "Anteile"))
        } label: {
            GroupTransactionHeader(shares: shares, includeSelf: includeSelf, scope: scope)
                .padding(.leading, ICONLEADING)
        }
    }
}

/// Aufbau wie layout3 in TransactionRowView: Icon links, Zweck oben, Betrag
/// rechts, Zeit unten links. Zweck, Zeit, Richtung und Signal-Kontakt stammen
/// aus demselben Sende-Vorgang und sind für alle Anteile gleich, daher reicht
/// der erste Anteil als Quelle.
struct GroupTransactionHeader: View {
    let shares: [TalerTransaction]
    let includeSelf: Bool?
    let scope: ScopeInfo

    var body: some View {
        if let first = shares.first {
            let title = shares.lazy
                .compactMap { $0.groupSummary?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? String(localized: "Gruppenzahlung")
            let progress = GroupTransactionSummary.progress(
                states: shares.map { $0.common.txState.major }, includeSelf: includeSelf)
            let total = GroupTransactionSummary.total(
                amounts: shares.map { $0.common.amountEffective }, includeSelf: includeSelf)
            let incoming = first.common.isIncoming
            let finished = progress.open == 0

            VStack(alignment: .leading, spacing: 4) {
                // Abstand 0 wie bei Einzelzeilen: dort ergibt er sich daraus, dass
                // die Betragszeile mit einem Spacer beginnt, hier beginnt sie mit Text.
                HStack(spacing: 0) {
                    TransactionIconBadge(type: first.common.type,
                                    foreColor: finished ? WalletColors().transactionColor(incoming)
                                                        : WalletColors().pendingColor(incoming),
                                         done: finished,
                                     incoming: incoming,
                                shouldConfirm: false,
                                     needsKYC: false)
                        .talerFont(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .talerFont(.headline)
                            .padding(.bottom, -2.0)
                        if let total {
                            HStack {
                                Text(includeSelf == true ? "gesamt (inkl. mir)" : "gesamt")
                                    .talerFont(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 0)
                                AmountV(scope, total, isNegative: total.isZero ? nil : !incoming)
                            }
                        }
                        TransactionTimeline(timestamp: first.common.timestamp,
                                            textColor: .primary, layout: 3, maxLines: 10)
                    }
                }
                Group {
                    SignalContactLine(transactionId: first.id)
                    GroupProgressBar(progress: progress)
                        .padding(.top, 2)
                    Text("\(progress.paid) bezahlt · \(progress.open) offen · \(progress.declined) abgelehnt")
                        .talerFont(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 44)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Dreiteiliger Balken: bezahlt (grün) / offen (neutral) / abgelehnt (rot).
/// Bei total == 0 (praktisch unerreichbar) ganz "offen".
struct GroupProgressBar: View {
    let progress: GroupProgress

    var body: some View {
        let hasData = progress.total > 0
        let parts: [(CGFloat, Color)] = [
            (hasData ? CGFloat(progress.paid) : 0, WalletColors().positive),
            (hasData ? CGFloat(progress.open) : 1, Color.secondary.opacity(0.4)),
            (hasData ? CGFloat(progress.declined) : 0, WalletColors().negative),
        ]
        let sum = parts.reduce(0) { $0 + $1.0 }
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(parts.indices, id: \.self) { index in
                    if parts[index].0 > 0 {
                        parts[index].1
                            .frame(width: geo.size.width * parts[index].0 / sum)
                    }
                }
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .accessibilityHidden(true)
    }
}

#endif
