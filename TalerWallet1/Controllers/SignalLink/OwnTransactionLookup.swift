//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Vergleichsschlüssel für eine taler://-Peer-URI: Scheme in Kleinbuchstaben,
/// Query und Fragment entfernt (Vertrag Abschnitt 6). Weitergegeben wird ohnehin
/// nur die bereinigte URI, gespeichert (talerUri in P2PTransactionDetails) kann
/// aber eine mit Query sein - deshalb wird beim Vergleich normalisiert.
/// Ungültiges -> nil. Die URI selbst wird nie geloggt (Inhaberpapier, Vertrag 2.6).
func signalUriMatchKey(_ uri: String) -> String? {
    guard let comps = URLComponents(string: uri),
          let scheme = comps.scheme?.lowercased()
    else { return nil }
    return scheme + "://" + (comps.host ?? "") + comps.percentEncodedPath
}

/// Sucht die eigene, ausgehenden Peer-Transaktion zu einer taler://-URI.
/// "Eigene" heißt: vom Nutzer selbst in Taler erzeugt, also peer-push-debit
/// (Geld senden) oder peer-pull-credit (Zahlung anfordern) mit gesetztem
/// talerUri - genau dann wird Signal "Abbrechen" statt "Annehmen" anbieten
/// (Vertrag Abschnitt 6, sonst würde die eigene Zahlung an sich selbst
/// angenommen). Durchsucht dazu die Transaktionen aller Scopes
/// (Balances -> Scopes -> getTransactionsV2), zuerst die offenen Vorgänge
/// (nur dort ist Abbrechen möglich), danach die abgeschlossenen.
/// Rückgabe: transactionId oder nil (dann ist die URI fremd und der normale
/// Annehmen-Ablauf läuft). Wird auch von T5 benutzt - API stabil halten.
func findOwnPeerTransaction(forTalerUri uri: String, model: WalletModel) async -> String? {
    guard let matchKey = signalUriMatchKey(uri) else { return nil }
    let stack = CallStack("SignalLink")
    guard let response = try? await model.getBalances(stack) else { return nil }
    for filter in [TransactionStateFilter.nonfinal, TransactionStateFilter.final] {
        for balance in response.0.balances {
            guard let transactions = try? await model.getTransactionsV2(stack,
                                                                  scope: balance.scopeInfo,
                                                          filterByState: filter)
            else { continue }
            for transaction in transactions {
                guard case .peer2peer(let p2p) = transaction else { continue }
                let type = p2p.common.type
                guard type == .peerPushDebit || type == .peerPullCredit,
                      let storedUri = p2p.details.talerUri,
                      signalUriMatchKey(storedUri) == matchKey
                else { continue }
                return p2p.common.transactionId
            }
        }
    }
    return nil
}

#endif
