//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import taler_swift

#if TALER_SIGNAL

/// Aufschlüsselung der Anteile einer Gruppen-Sammelzeile
/// (Android-Gegenstück: transactions/GroupTransactionSummary.kt).
/// Der Eigenanteil des Erstellers (includeSelf == true) zählt sofort als
/// bezahlt - für ihn gibt es keinen Transfer, sonst erreichte der Balken
/// nie 100 %.
struct GroupProgress: Equatable {
    var paid: Int
    var open: Int
    var declined: Int
    var total: Int
}

enum GroupTransactionSummary {

    private static let declinedStates: Set<TransactionMajorState> =
        [.aborted, .failed, .expired, .deleted]

    static func progress(states: [TransactionMajorState], includeSelf: Bool?) -> GroupProgress {
        let selfCounts = includeSelf == true ? 1 : 0
        let declined = states.filter { declinedStates.contains($0) }.count
        let paid = states.filter { $0 == .done }.count + selfCounts
        let total = states.count + selfCounts
        return GroupProgress(paid: paid, open: total - paid - declined,
                             declined: declined, total: total)
    }

    /// Summe aller sichtbaren Anteile, plus ein weiterer gleich großer
    /// Anteil bei includeSelf (AmountSplit teilt gleichmäßig). nil bei
    /// leerer Liste oder Rechenfehler (z.B. gemischte Währungen).
    static func total(amounts: [Amount], includeSelf: Bool?) -> Amount? {
        guard let first = amounts.first else { return nil }
        var sum = first.copy()
        for amount in amounts.dropFirst() {
            guard let next = try? sum + amount else { return nil }
            sum = next
        }
        if includeSelf == true {
            return try? sum + first
        }
        return sum
    }

    /// Fasst Elemente mit derselben groupId zu einer Gruppe zusammen, an der
    /// Position ihres ersten Auftretens (zeitliche Sortierung bleibt). Ist
    /// von einer Gruppe nur ein Anteil sichtbar (z.B. Filter), bleibt er
    /// ein Einzeleintrag.
    static func groupEntries<T>(_ items: [T],
                                groupInfo: (T) -> GroupShareStore.Info?
    ) -> [TransactionListEntry<T>] {
        let infos = items.map(groupInfo)
        var membersByGroup: [String: [T]] = [:]
        for (item, info) in zip(items, infos) {
            guard let info else { continue }
            membersByGroup[info.groupId, default: []].append(item)
        }
        var emitted = Set<String>()
        var result: [TransactionListEntry<T>] = []
        for (item, info) in zip(items, infos) {
            guard let info, let members = membersByGroup[info.groupId], members.count > 1 else {
                result.append(.single(item))
                continue
            }
            if emitted.insert(info.groupId).inserted {
                result.append(.group(groupId: info.groupId, shares: members,
                                     includeSelf: info.includeSelf))
            }
        }
        return result
    }
}

/// Anzeige-Eintrag der Transaktionsliste: Einzeltransaktion oder
/// Sammelzeile für mehrere Anteile eines Gruppen-Splits.
enum TransactionListEntry<T> {
    case single(T)
    case group(groupId: String, shares: [T], includeSelf: Bool?)
}

extension TalerTransaction {
    /// Vom Nutzer eingegebener Zweck einer Peer-Transaktion (Titel der
    /// Sammelzeile).
    var groupSummary: String? {
        if case .peer2peer(let p2p) = self {
            return p2p.details.info.summary
        }
        return nil
    }
}

#endif
