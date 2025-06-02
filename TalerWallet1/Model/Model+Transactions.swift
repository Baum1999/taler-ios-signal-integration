/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import SymLog

// MARK: -
extension WalletModel {
    static func completedTransactions(_ transactions: [TalerTransaction]) -> [TalerTransaction] {
        transactions.filter { transaction in
            !transaction.isPending
        }
    }
    static func pendingTransactions(_ transactions: [TalerTransaction]) -> [TalerTransaction] {
        transactions.filter { transaction in
            transaction.isPending
        }
    }
}
// MARK: -
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactions: WalletBackendFormattedRequest {
    func operation() -> String { "getTransactions" }
    func args() -> Args { Args(scopeInfo: scopeInfo, currency: currency, search: search,
                                    sort: sort, filterByState: filterByState, includeRefreshes: includeRefreshes) }
    var scopeInfo: ScopeInfo?
    var currency: String?
    var search: String?
    var sort: String?
    var filterByState: TransactionStateFilter?
    var includeRefreshes: Bool?
    struct Args: Encodable {
        var scopeInfo: ScopeInfo?
        var currency: String?
        var search: String?
        var sort: String?
        var filterByState: TransactionStateFilter?
        var includeRefreshes: Bool?
    }

    struct Response: Decodable {                    // list of transactions
        var transactions: [TalerTransaction]
    }
}
enum TransactionStateFilter: String, Codable {
    case done
    case final          // done, aborted, expired, ...
    case nonfinal       // pending, dialog, suspended, aborting
}
struct TransactionOffset: Codable {
    var txID: String
    var txTime: Timestamp
}
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactionsV2: WalletBackendFormattedRequest {
    func operation() -> String { "getTransactionsV2" }
    func args() -> Args { Args(scopeInfo: scope,
                           filterByState: filterByState,
                        includeRefreshes: includeRefreshes,
                                   limit: -limit,               // descending
                     offsetTransactionId: offset?.txID,
                         offsetTimestamp: offset?.txTime) }

    var scope: ScopeInfo?
    var filterByState: TransactionStateFilter?
    var limit: Int
    var offset: TransactionOffset?
    var includeRefreshes: Bool?
    struct Args: Encodable {
        var scopeInfo: ScopeInfo?
        var filterByState: TransactionStateFilter?
        var includeRefreshes: Bool?
        var limit: Int
        var offsetTransactionId: String?
        var offsetTimestamp: Timestamp?
    }

    struct Response: Decodable {                    // list of transactions
        var transactions: [TalerTransaction]
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
    /// ask wallet-core for its list of transactions filtered by state
    nonisolated func getTransactionsV2(_ stack: CallStack,
                                         scope: ScopeInfo,
                                 filterByState: TransactionStateFilter,
                                         limit: Int = 1_000_000,
                                        offset: TransactionOffset? = nil,
                              includeRefreshes: Bool = false,
                                   viewHandles: Bool = false)
      async throws -> [TalerTransaction] {
        let request = GetTransactionsV2(scope: scope,
                                filterByState: filterByState,
                                        limit: limit,
                                       offset: offset,
                             includeRefreshes: includeRefreshes)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response.transactions
    }
    // MARK: -
    /// abort the specified transaction from Wallet-Core. No networking involved
    nonisolated func abortTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = AbortTransaction(transactionId: transactionId)
        logger.notice("abortTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    /// delete the specified transaction from Wallet-Core. No networking involved
    nonisolated func deleteTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = DeleteTransaction(transactionId: transactionId)
        logger.notice("deleteTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func failTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = FailTransaction(transactionId: transactionId)
        logger.notice("failTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func suspendTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = SuspendTransaction(transactionId: transactionId)
        logger.notice("suspendTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func resumeTransaction(transactionId: String, viewHandles: Bool = false) async throws {
        let request = ResumeTransaction(transactionId: transactionId)
        logger.notice("resumeTransaction: \(transactionId, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
