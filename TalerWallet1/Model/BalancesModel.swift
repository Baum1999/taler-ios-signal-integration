/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
class BalancesModel: WalletModel {
    @Published var balances: [Balance]

    override init(_ symbol: Int = -1) {
        balances = []                        // empty, but not nil
        super.init(symbol)
    }
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
    var scopeInfo: ScopeInfo

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
    @MainActor func fetchBalancesM()
      async {          // M for MainActor
        do {
            let request = GetBalances()
            let response = try await sendRequestM(request, ASYNCDELAY)
            balances = response.balances                // trigger view update in BalancesListView
        } catch {
            balances = []
        }
    }
}

// MARK: -
extension BalancesModel {
    private static var currencies: [String] = []            // names of currencies
    private static var models: [BalancesModel] = []         // one model per currency

    static func model(currency: String) -> BalancesModel {
        if let index = BalancesModel.currencies.firstIndex(of:currency) {
            let model = BalancesModel.models[index]
            return model
        } else {        // new currency
            let model = BalancesModel()
            BalancesModel.models.append(model)
            BalancesModel.currencies.append(currency)
            return model
        }
    }
}
