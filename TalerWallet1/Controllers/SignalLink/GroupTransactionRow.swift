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

/// Auf-/zuklappbare Sammelzeile für einen Gruppen-Split
/// (Android-Gegenstück: GroupTransactionRow in TransactionsComposable.kt).
/// Aufgeklappt bleibt jeder Anteil eine ganz normale Zeile der Liste -
/// Detailansicht und Löschen funktionieren wie bei Einzeltransaktionen.
struct GroupTransactionRow<Row: View>: View {
    let groupId: String
    let shares: [TalerTransaction]
    let includeSelf: Bool?
    let scope: ScopeInfo
    @ViewBuilder let row: (TalerTransaction) -> Row

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(shares, id: \.self) { tx in
                row(tx)
            }
        } label: {
            GroupTransactionHeader(shares: shares, includeSelf: includeSelf, scope: scope)
        }
    }
}

struct GroupTransactionHeader: View {
    let shares: [TalerTransaction]
    let includeSelf: Bool?
    let scope: ScopeInfo

    var body: some View {
        let title = shares.lazy
            .compactMap { $0.groupSummary?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? String(localized: "Gruppenzahlung")
        let progress = GroupTransactionSummary.progress(
            states: shares.map { $0.common.txState.major }, includeSelf: includeSelf)
        let total = GroupTransactionSummary.total(
            amounts: shares.map { $0.common.amountEffective }, includeSelf: includeSelf)

        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .talerFont(.headline)
            Text("\(shares.count) Empfänger")
                .talerFont(.subheadline)
                .foregroundColor(.secondary)
            if let total {
                HStack(spacing: 4) {
                    AmountV(scope, total)
                    Text(includeSelf == true ? "gesamt (inkl. mir)" : "gesamt")
                }
                .talerFont(.subheadline)
                .foregroundColor(.secondary)
            }
            GroupProgressBar(progress: progress)
                .padding(.top, 2)
            Text("\(progress.paid) bezahlt · \(progress.open) offen · \(progress.declined) abgelehnt")
                .talerFont(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
