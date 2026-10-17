//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Sucht die EMPFANGENE Zahlung zu einer taler://pay-push-URI (Android-
/// Gegenstück: PeerManager.resolveReceivedPeerPushCreditId).
///
/// Ein Vergleich über die Transaktionsliste findet nichts: laut
/// Transaction.swift ist details.talerUri "only if we initiated the
/// transaction" - bei einer EMPFANGENEN Zahlung also immer nil. Deshalb
/// wird die URI wie beim Empfangen über preparePeerPushCredit an
/// wallet-core übergeben, das sie (idempotent) zur bereits bestehenden
/// peer-push-credit-Transaktion auflöst, und diese wird anschließend
/// über getTransactionById geladen.
///
/// Zurückgegeben wird die Transaktion nur, wenn es eine peer2peer-
/// Transaktion vom Typ scanPushCredit (wallet-core: "peer-push-credit")
/// im Zustand done ist - nur eine abgeschlossene empfangene Zahlung kann
/// erstattet werden, eine offene wäre kein Geld des Empfängers. T4
/// braucht Betrag und Zweck aus dieser verifizierten Quelle (Eiserne
/// Regel 5). Die URI selbst wird nie geloggt (Inhaberpapier).
func findIncomingPeerPushCredit(forTalerUri uri: String, model: WalletModel) async -> TalerTransaction? {
    guard let prepared = try? await model.preparePeerPushCredit(uri) else { return nil }
    guard let transaction = try? await model.getTransactionById(prepared.transactionId,
                                                                includeContractTerms: false,
                                                                viewHandles: true)
    else { return nil }
    guard case .peer2peer(let p2p) = transaction,
          p2p.common.type == .scanPushCredit,
          p2p.common.isDone
    else { return nil }
    return transaction
}

#endif
