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
import os.log

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
enum TransactionStateFilter: String, Codable {
    case done
    case final              // done, aborted, expired, ...
    case nonfinal           // pending, dialog, suspended, aborting
    case nonfinalApproved = "nonfinal-approved"
    case nonfinalDialog = "nonfinal-dialog"
}
struct TransactionOffset: Codable {
    var txID: String
    var txTime: Timestamp
}
/// A request to get the transactions in the wallet's history.
fileprivate struct GetTransactionsV2: WalletBackendFormattedRequest {
    var operation: String { "getTransactionsV2" }
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

        enum CodingKeys: String, CodingKey { case transactions }

        /// Decode the array element by element so that ONE transaction wallet-core sends
        /// in a shape this app does not understand costs us that transaction, not the
        /// user's entire history. Decoding `[TalerTransaction]` directly throws on the
        /// first bad element and every caller's `try?` then renders an empty list.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let wrapped = try container.decode([SkippableTransaction].self, forKey: .transactions)
            self.transactions = wrapped.compactMap { $0.transaction }
        }
    }
}

/// Wrapper whose own decoding never fails, so a failed element consumes its array slot
/// instead of aborting the array. See GetTransactionsV2.Response.
fileprivate struct SkippableTransaction: Decodable {
    let transaction: TalerTransaction?

    init(from decoder: Decoder) throws {
        do {
            transaction = try TalerTransaction(from: decoder)
        } catch {
            transaction = nil
            let details = String(describing: error)
            Logger(subsystem: "net.taler.gnu", category: "Transactions")
                .error("dropped an undecodable transaction: \(details, privacy: .public)")
        }
    }
}
/// A request to abort a wallet transaction by ID.
struct AbortTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "abortTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct DeleteTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "deleteTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to delete a wallet transaction by ID.
struct FailTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "failTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct SuspendTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "suspendTransaction" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
/// A request to suspend a wallet transaction by ID.
struct ResumeTransaction: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "resumeTransaction" }
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
