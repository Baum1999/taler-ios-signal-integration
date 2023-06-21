/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
extension WalletModel {
    static func specialTransactions(_ transactions: [Transaction]) -> [Transaction] {
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
    struct Response: Decodable {}
    func operation() -> String { return "abortTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
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
/// A request to suspend a wallet transaction by ID.
struct SuspendTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { return "suspendTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct ResumeTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { return "resumeTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
// MARK: -
extension WalletModel {
    /// ask wallet-core for its list of transactions filtered by searchString
    func fetchTransactionsT(currency: String? = nil, searchString: String? = nil)
    async -> [Transaction] {                                          // might be called from a background thread itself
        do {
            let request = GetTransactions(currency: currency, search: searchString)
            logger.info("getTransactions")
            let response = try await sendRequest(request, ASYNCDELAY)
            return response.transactions
        } catch {
            logger.error("getTransactions failed: \(error)")
            return []
        }
    }
    /// fetch transactions from Wallet-Core. No networking involved
    @MainActor func fetchTransactionsM(currency: String? = nil, searchString: String? = nil)
    async -> [Transaction] {    // M for MainActor
        return await fetchTransactionsT(currency: currency, searchString: searchString)
    }

    func abortTransactionT(transactionId: String)
      async throws {          // might be called from a background thread itself
        let request = AbortTransaction(transactionId: transactionId)
        logger.info("abortTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func abortTransactionM(transactionId: String)
    async throws {             // M for MainActor
        try await abortTransactionT(transactionId: transactionId)
    }

    func deleteTransactionT(transactionId: String)
      async throws {          // might be called from a background thread itself
        let request = DeleteTransaction(transactionId: transactionId)
        logger.info("deleteTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func deleteTransactionM(transactionId: String)
      async throws {              // M for MainActor
        try await deleteTransactionT(transactionId: transactionId)
    }

    func suspendTransactionT(transactionId: String)
      async throws {          // might be called from a background thread itself
        let request = SuspendTransaction(transactionId: transactionId)
        logger.info("suspendTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func suspendTransactionM(transactionId: String)
      async throws {               // M for MainActor
        try await suspendTransactionT(transactionId: transactionId)
    }

    func resumeTransactionT(transactionId: String)
    async throws {            // might be called from a background thread itself
        let request = ResumeTransaction(transactionId: transactionId)
        logger.info("resumeTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
    /// delete the specified transaction from Wallet-Core. No networking involved
    @MainActor func resumeTransactionM(transactionId: String)
      async throws {              // M for MainActor
        try await resumeTransactionT(transactionId: transactionId)
    }
}
