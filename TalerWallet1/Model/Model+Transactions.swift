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
    static func completedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            !transaction.isPending
        }
    }
    static func pendingTransactions(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in
            transaction.isPending
        }
    }
}

// MARK: -
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactions: WalletBackendFormattedRequest {
    func operation() -> String { "getTransactions" }
//    func operation() -> String { "testingGetSampleTransactions" }
    func args() -> Args { Args(scopeInfo: scopeInfo, currency: currency, search: search, sort: sort, includeRefreshes: includeRefreshes) }

    var scopeInfo: ScopeInfo?
    var currency: String?
    var search: String?
    var sort: String?
    var includeRefreshes: Bool?
    struct Args: Encodable {
        var scopeInfo: ScopeInfo?
        var currency: String?
        var search: String?
        var sort: String?
        var includeRefreshes: Bool?
    }

    struct Response: Decodable {                    // list of transactions
        var transactions: [Transaction]
    }
}
/// A request to abort a wallet transaction by ID.
struct AbortTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "abortTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct DeleteTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "deleteTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct FailTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "failTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct SuspendTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "suspendTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct ResumeTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "resumeTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
// MARK: -
extension WalletModel {
    /// ask wallet-core for its list of transactions filtered by searchString
    func transactionsT(_ stack: CallStack, scopeInfo: ScopeInfo, searchString: String? = nil,
                       sort: String = "descending", includeRefreshes: Bool = false, viewHandles: Bool = false)
    async throws -> [Transaction] {
        let request = GetTransactions(scopeInfo: scopeInfo, currency: scopeInfo.currency, search: searchString, sort: sort, includeRefreshes: includeRefreshes)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.transactions
    }
    /// fetch transactions from Wallet-Core. No networking involved
    @MainActor func transactionsMA(_ stack: CallStack, scopeInfo: ScopeInfo, searchString: String? = nil, sort: String = "descending", viewHandles: Bool = false)
    async throws -> [Transaction] {    // M for MainActor
        return try await transactionsT(stack.push(), scopeInfo: scopeInfo, searchString: searchString, sort: sort, viewHandles: viewHandles)
    }

    /// abort the specified transaction from Wallet-Core. No networking involved
    func abortTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = AbortTransaction(transactionId: transactionId)
        logger.notice("abortTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }

    /// delete the specified transaction from Wallet-Core. No networking involved
    func deleteTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = DeleteTransaction(transactionId: transactionId)
        logger.notice("deleteTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }

    func failTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = FailTransaction(transactionId: transactionId)
        logger.notice("failTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }

    func suspendTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = SuspendTransaction(transactionId: transactionId)
        logger.notice("suspendTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }

    func resumeTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = ResumeTransaction(transactionId: transactionId)
        logger.notice("resumeTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }
}
