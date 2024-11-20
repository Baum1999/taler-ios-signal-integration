/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: common structures
struct PeerContractTerms: Codable {
    let amount: Amount
    let summary: String
    let purse_expiration: Timestamp
}
// MARK: - max PeerPushDebit amount
/// Check if initiating a peer push payment is possible, check fees
fileprivate struct AmountResponse: Codable {
    let effectiveAmount: Amount?
    let rawAmount: Amount
}
fileprivate struct GetMaxPeerPushDebitAmount: WalletBackendFormattedRequest {
    typealias Response = AmountResponse
    func operation() -> String { "getMaxPeerPushDebitAmount" }
    func args() -> Args { Args(currency: scope.currency,
                          restrictScope: scope) }
    var scope: ScopeInfo
    struct Args: Encodable {
        var currency: String
        var restrictScope: ScopeInfo
    }
}
extension WalletModel {
    nonisolated func getMaxPeerPushDebitAmount(_ scope: ScopeInfo,
                                           viewHandles: Bool = false)
      async throws -> Amount {
        let request = GetMaxPeerPushDebitAmount(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.rawAmount
    }
} // getMaxPeerPushAmount
// MARK: - check PeerPushDebit
struct CheckPeerPushDebitResponse: Codable {
    let exchangeBaseUrl: String?                // API "2:0:1"
    let amountRaw: Amount
    let amountEffective: Amount
    let maxExpirationDate: Timestamp?           // API "2:0:1" TODO: limit expiration (30 days or 7 days)
}
fileprivate struct CheckPeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = CheckPeerPushDebitResponse
    func operation() -> String { "checkPeerPushDebit" }
    func args() -> Args { Args(amount: amount,
                        restrictScope: scope,
                 clientCancellationId: "cancel") }
    var amount: Amount
    var scope: ScopeInfo
    struct Args: Encodable {
        var amount: Amount
        var restrictScope: ScopeInfo
        var clientCancellationId: String?
    }
}
extension WalletModel {
    nonisolated func checkPeerPushDebit(_ amount: Amount,
                                           scope: ScopeInfo,
                                     viewHandles: Bool = false)
      async throws -> CheckPeerPushDebitResponse {
        let request = CheckPeerPushDebit(amount: amount, scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // checkPeerPushDebit
// MARK: - Initiate PeerPushDebit
/// Initiate an outgoing peer push payment, send coins
struct InitiatePeerPushDebitResponse: Codable {
    let contractPriv: String
    let mergePriv: String
    let pursePub: String
    let exchangeBaseUrl: String
    let talerUri: String?
    let transactionId: String
}
fileprivate struct InitiatePeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = InitiatePeerPushDebitResponse
    func operation() -> String { "initiatePeerPushDebit" }
    func args() -> Args { Args(restrictScope: scope,
                        partialContractTerms: terms) }
    var scope: ScopeInfo
    var terms: PeerContractTerms
    struct Args: Encodable {
        var restrictScope: ScopeInfo
        var partialContractTerms: PeerContractTerms
    }
}
extension WalletModel {
    nonisolated func initiatePeerPushDebit(scope: ScopeInfo,
                                           terms: PeerContractTerms,
                                     viewHandles: Bool = false)
      async throws -> InitiatePeerPushDebitResponse {
        let request = InitiatePeerPushDebit(scope: scope, terms: terms)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // initiatePeerPushDebit
// MARK: - PeerPullCredit
/// Check fees before sending a request(invoice) to another wallet
struct CheckPeerPullCreditResponse: Codable {
    let scopeInfo: ScopeInfo?
    let exchangeBaseUrl: String?
    let amountRaw: Amount
    let amountEffective: Amount
    var numCoins: Int?                  // Number of coins this amountEffective will create
}
fileprivate struct CheckPeerPullCredit: WalletBackendFormattedRequest {
    typealias Response = CheckPeerPullCreditResponse
    func operation() -> String { "checkPeerPullCredit" }
    func args() -> Args { Args(amount: amount,
                        restrictScope: scope,
                      exchangeBaseUrl: scope?.url,
                 clientCancellationId: "cancel") }
    var amount: Amount
    var scope: ScopeInfo?
    struct Args: Encodable {
        var amount: Amount
        var restrictScope: ScopeInfo?
        var exchangeBaseUrl: String?
        var clientCancellationId: String?
    }
}
extension WalletModel {
    nonisolated func checkPeerPullCredit(_ amount: Amount,
                                            scope: ScopeInfo,
                                      viewHandles: Bool = false)
      async throws -> CheckPeerPullCreditResponse {
        let request = CheckPeerPullCredit(amount: amount, scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // checkPeerPullCredit
// - - - - - -
/// Initiate an outgoing peer pull payment, send a request(invoice)
struct InitiatePeerPullCreditResponse: Codable {
    let talerUri: String
    let transactionId: String
}
fileprivate struct InitiatePeerPullCredit: WalletBackendFormattedRequest {
    typealias Response = InitiatePeerPullCreditResponse
    func operation() -> String { "initiatePeerPullCredit" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl,
                          partialContractTerms: partialContractTerms) }
    var exchangeBaseUrl: String?
    var partialContractTerms: PeerContractTerms
    struct Args: Encodable {
        var exchangeBaseUrl: String?
        var partialContractTerms: PeerContractTerms
    }
}
extension WalletModel {
    nonisolated func initiatePeerPullCredit(_ baseURL: String?,
                                                terms: PeerContractTerms,
                                          viewHandles: Bool = false)
      async throws -> InitiatePeerPullCreditResponse {
        let request = InitiatePeerPullCredit(exchangeBaseUrl: baseURL,
                                        partialContractTerms: terms)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // initiatePeerPullCredit
// MARK: - PeerPushCredit
/// Prepare an incoming peer push payment, receive coins
struct PreparePeerPushCreditResponse: Codable {
    let contractTerms: PeerContractTerms
    let amountRaw: Amount
    let amountEffective: Amount
    // TODO: the dialog transaction is already created in the local DB - must either accept or delete
    let transactionId: String
    let exchangeBaseUrl: String         // need (exchange.tosStatus == .accepted) for incoming coins
    let scopeInfo: ScopeInfo
}
fileprivate struct PreparePeerPushCredit: WalletBackendFormattedRequest {
    typealias Response = PreparePeerPushCreditResponse
    func operation() -> String { "preparePeerPushCredit" }
    func args() -> Args { Args(talerUri: talerUri) }

    var talerUri: String
    struct Args: Encodable {
        var talerUri: String
    }
}
extension WalletModel {
    nonisolated func preparePeerPushCredit(_ talerUri: String,
                                          viewHandles: Bool = false)
      async throws -> PreparePeerPushCreditResponse {
        let request = PreparePeerPushCredit(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // preparePeerPushCredit
// - - - - - -
/// Accept an incoming peer push payment
fileprivate struct AcceptPeerPushCredit: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "confirmPeerPushCredit" } // should be "acceptPeerPushCredit"
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
extension WalletModel {
    nonisolated func acceptPeerPushCredit(_ transactionId: String,
                                              viewHandles: Bool = false)
      async throws -> Decodable {
        let request = AcceptPeerPushCredit(transactionId: transactionId)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // acceptPeerPushCredit
// MARK: - PeerPullDebit
/// Prepare an incoming peer push request(invoice), pay coins
struct PreparePeerPullDebitResponse: Codable {
    let contractTerms: PeerContractTerms
    let amountRaw: Amount
    let amountEffective: Amount
    // TODO: the dialog transaction is already created in the local DB - must either accept or delete
    let transactionId: String
//    let exchangeBaseUrl: String       use scope instead
    let scopeInfo: ScopeInfo
}
fileprivate struct PreparePeerPullDebit: WalletBackendFormattedRequest {
    typealias Response = PreparePeerPullDebitResponse
    func operation() -> String { "preparePeerPullDebit" }
    func args() -> Args { Args(talerUri: talerUri) }

    var talerUri: String
    struct Args: Encodable {
        var talerUri: String
    }
}
extension WalletModel {
    nonisolated func preparePeerPullDebit(_ talerUri: String,
                                         viewHandles: Bool = false)
      async throws -> PreparePeerPullDebitResponse {
        let request = PreparePeerPullDebit(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // preparePeerPullDebit
// - - - - - -
/// Confirm incoming peer push request(invoice) and pay
fileprivate struct ConfirmPeerPullDebit: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "confirmPeerPullDebit" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
extension WalletModel {
    nonisolated func confirmPeerPullDebit(_ transactionId: String,
                                              viewHandles: Bool = false)
      async throws -> Decodable {
        let request = ConfirmPeerPullDebit(transactionId: transactionId)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // confirmPeerPullDebit
