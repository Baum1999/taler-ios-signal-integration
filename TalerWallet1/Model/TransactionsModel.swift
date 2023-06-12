/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
class TransactionsModel: WalletModel {
    @Published var transactions: [Transaction]

    static func specialTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            transaction.isSpecial
        }
    }
    var specialTransactions: [Transaction] {
        transactions.filter { transaction in
            transaction.isSpecial
        }
    }

    static func completedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            transaction.isDone
        }
    }
    static func pendingTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            transaction.isPending
        }
    }
    static func uncompletedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            !transaction.isDone && !transaction.isPending
        }
    }

    override init(_ symbol: Int = -1) {
        transactions = []                // empty, but not nil
        super.init(symbol)
    }
}

// MARK: -
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactions: WalletBackendFormattedRequest {
    func operation() -> String { return "getTransactions" }
//    func operation() -> String { return "testingGetSampleTransactions" }
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
/// A request to abort a wallet transaction by ID.
struct AbortTransaction: WalletBackendFormattedRequest {
    func operation() -> String { return "abortTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }

    struct Response: Decodable {}
}
/// A request to delete a wallet transaction by ID.
struct DeleteTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { return "deleteTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }
}

// MARK: -
extension TransactionsModel {
    /// ask wallet-core for its list of transactions filtered by searchString
    func fetchTransactions(currency: String?) async {             // might be called from a background thread itself
        await fetchTransactionsM(currency: currency, searchString: nil)
    }
    /// fetch transactions from Wallet-Core. No networking involved
    @MainActor func fetchTransactionsM(currency: String? = nil, searchString: String? = nil)
      async {              // M for MainActor
        do {
            let request = GetTransactions(currency: currency, search: searchString)
            let response = try await sendRequestM(request, ASYNCDELAY)
            transactions = response.transactions        // trigger view update in TransactionsListView
        } catch {
            transactions = []
        }
    }

    func abortTransaction(transactionId: String) async throws {        // might be called from a background thread itself
        try await abortTransactionM(transactionId: transactionId)      // call deleteTransactionM on main thread
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func abortTransactionM(transactionId: String)
    async throws {                // M for MainActor
        do {
            let request = AbortTransaction(transactionId: transactionId)
            let _ = try await sendRequestT(request, ASYNCDELAY)
        } catch {       // rethrows
            symLog?.log(error.localizedDescription)
            throw error
        }
    }

    func deleteTransaction(transactionId: String) async throws {        // might be called from a background thread itself
        try await deleteTransactionM(transactionId: transactionId)      // call deleteTransactionM on main thread
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func deleteTransactionM(transactionId: String)
    async throws {                // M for MainActor
        do {
            let request = DeleteTransaction(transactionId: transactionId)
            let _ = try await sendRequestT(request, ASYNCDELAY)
        } catch {       // rethrows
            symLog?.log(error.localizedDescription)
            throw error
        }
    }
}

// MARK: -
extension TransactionsModel {
    private static var currencies: [String] = []            // names of currencies
    private static var models: [TransactionsModel] = []     // one model per currency

    static func model(currency: String) -> TransactionsModel {
        if let index = TransactionsModel.currencies.firstIndex(of:currency) {
            let model = TransactionsModel.models[index]
            return model
        } else {        // new currency
            let model = TransactionsModel()
            TransactionsModel.models.append(model)
            TransactionsModel.currencies.append(currency)
            return model
        }
    }
}
