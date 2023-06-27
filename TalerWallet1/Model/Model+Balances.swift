/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
/// A currency balance
struct Balance: Decodable, Hashable {
    var available: Amount
    var scopeInfo: ScopeInfo
    var requiresUserInput: Bool
    var hasPendingTransactions: Bool

    public static func == (lhs: Balance, rhs: Balance) -> Bool {
        return lhs.available == rhs.available &&
        lhs.scopeInfo == rhs.scopeInfo &&
        lhs.requiresUserInput == rhs.requiresUserInput &&
        lhs.hasPendingTransactions == rhs.hasPendingTransactions
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(available)
        hasher.combine(scopeInfo)
        hasher.combine(requiresUserInput)
        hasher.combine(hasPendingTransactions)
    }
}
// MARK: -
/// A request to get the balances held in the wallet.
fileprivate struct Balances: WalletBackendFormattedRequest {
    func operation() -> String { return "getBalances" }
    func args() -> Args { return Args() }

    struct Args: Encodable {}                           // no arguments needed

    struct Response: Decodable {                        // list of balances
        var balances: [Balance]
    }
}
// MARK: -
extension WalletModel {
    /// fetch Balances from Wallet-Core. No networking involved
    @MainActor func balancesM()
      async -> [Balance] {          // M for MainActor
        do {
            let request = Balances()
            let response = try await sendRequest(request, ASYNCDELAY)
            return response.balances                // trigger view update in BalancesListView
        } catch {
            logger.error("balancesM failed: \(error)")
            return []
        }
    }
}
