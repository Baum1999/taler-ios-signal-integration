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
    func args() -> Args { return Args(currency: currency, search: search, sort: sort) }

    var currency: String?
    var search: String?
    var sort: String?
    struct Args: Encodable {
        var currency: String?
        var search: String?
        var sort: String?
    }

    struct Response: Decodable {                    // list of transactions
        var transactions: [Transaction]
    }
}
/// A request to abort a wallet transaction by ID.
struct AbortTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "abortTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct DeleteTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "deleteTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct FailTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "failTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct SuspendTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "suspendTransaction" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct ResumeTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
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
    func transactionsT(_ stack: CallStack, currency: String? = nil, searchString: String? = nil, sort: String = "descending")
    async -> [Transaction] {                                          // might be called from a background thread itself
        do {
            let request = GetTransactions(currency: currency, search: searchString, sort: sort)
            let response = try await sendRequest(request, ASYNCDELAY)
            return response.transactions
        } catch {
            return []
        }
    }
    /// fetch transactions from Wallet-Core. No networking involved
    @MainActor func transactionsMA(_ stack: CallStack, currency: String? = nil, searchString: String? = nil, sort: String = "descending")
    async -> [Transaction] {    // M for MainActor
        return await transactionsT(stack.push(), currency: currency, searchString: searchString, sort: sort)
    }

    /// abort the specified transaction from Wallet-Core. No networking involved
    func abortTransaction(transactionId: String) async throws {
        let request = AbortTransaction(transactionId: transactionId)
        logger.info("abortTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }

    /// delete the specified transaction from Wallet-Core. No networking involved
    func deleteTransaction(transactionId: String) async throws {
        let request = DeleteTransaction(transactionId: transactionId)
        logger.info("deleteTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }

    func failTransaction(transactionId: String) async throws {
        let request = FailTransaction(transactionId: transactionId)
        logger.info("failTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }

    func suspendTransaction(transactionId: String) async throws {
        let request = SuspendTransaction(transactionId: transactionId)
        logger.info("suspendTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }

    func resumeTransaction(transactionId: String) async throws {
        let request = ResumeTransaction(transactionId: transactionId)
        logger.info("resumeTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
}
