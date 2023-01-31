/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
class TransactionsModel: WalletModel {
    @Published var transactions: [Transaction]?             // update view
}
//extension Transaction {
//    func exchangeBaseUrl() -> String {
//        switch detail {
//            case .withdrawal(let transactionWithdrawal):
//                return transactionWithdrawal.exchangeBaseUrl
//        }
//    }
//}

// MARK: -
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactions: WalletBackendFormattedRequest {
    func operation() -> String { return "getTransactions" }
    func args() -> Args { return Args(currency: currency, search: search) }

    var currency: String?
    var search: String?

    struct Args: Encodable {
        var currency: String?
        var search: String?
    }

    struct Response: Decodable {                    // list of transactions
        var transactions: [Transaction]
    }
}
// MARK: -
extension TransactionsModel {
    /// ask wallet-core for its list of transactions filtered by searchString
    func fetchTransactions() async throws {             // might be called from a background thread itself
        try await fetchTransactions(currency: nil, searchString: nil)
    }
    /// fetch Balances from Wallet-Core. No networking involved
    @MainActor func fetchTransactions(currency: String? = nil, searchString: String? = nil)
      async throws {
        do {
            let request = GetTransactions(currency: nil, search: nil)
            let response = try await sendRequest(request, ASYNCDELAY)
            transactions = response.transactions        // trigger view update in TransactionsListView
        } catch {
            throw error
        }
    }
}
