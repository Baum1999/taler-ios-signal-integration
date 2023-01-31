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

class BalancesModel: WalletModel {
    @Published var balances: [Balance]?                 // update view
}
// MARK: -
/// A request to get the balances held in the wallet.
fileprivate struct GetBalances: WalletBackendFormattedRequest {
    func operation() -> String { return "getBalances" }
    func args() -> Args { return Args() }

    struct Args: Encodable {}                           // no arguments needed

    struct Response: Decodable {                        // list of balances
        var balances: [Balance]
    }
}
// MARK: -
/// A currency balance
struct Balance: Decodable, Hashable {
    var available: Amount
    var pendingIncoming: Amount
    var pendingOutgoing: Amount
    var hasPendingTransactions: Bool
    var requiresUserInput: Bool

    public static func == (lhs: Balance, rhs: Balance) -> Bool {
        return lhs.available == rhs.available &&
            lhs.pendingIncoming == rhs.pendingIncoming &&
            lhs.pendingOutgoing == rhs.pendingOutgoing &&
            lhs.hasPendingTransactions == rhs.hasPendingTransactions &&
            lhs.requiresUserInput == rhs.requiresUserInput
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(available)
        hasher.combine(pendingIncoming)
        hasher.combine(pendingOutgoing)
        hasher.combine(hasPendingTransactions)
        hasher.combine(requiresUserInput)
    }
}
// MARK: -
extension BalancesModel {
    /// fetch Balances from Wallet-Core. No networking involved
    @MainActor func fetchBalances() async throws {
        do {
            let request = GetBalances()
            let response = try await sendRequest(request, ASYNCDELAY)
            balances = response.balances                // trigger view update in CurrenciesListView
        } catch {
            throw error
        }
    }
}
