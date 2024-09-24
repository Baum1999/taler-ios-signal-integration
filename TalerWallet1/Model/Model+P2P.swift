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
// MARK: - PeerPushDebit
/// Check if initiating a peer push payment is possible, check fees
fileprivate struct AmountResponse: Codable {
    let effectiveAmount: Amount?
    let rawAmount: Amount
}
fileprivate struct GetMaxPeerPushDebitAmount: WalletBackendFormattedRequest {
    typealias Response = AmountResponse
    func operation() -> String { "getMaxPeerPushDebitAmount" }
    func args() -> Args { Args(currency: currency, restrictScope: scope) }

    var currency: String
    var scope: ScopeInfo
    struct Args: Encodable {
        var currency: String
        var restrictScope: ScopeInfo
    }
}
extension WalletModel {
    @MainActor                 // M for MainActor
    func getMaxPeerPushDebitAmountM(_ currency: String, scope: ScopeInfo, viewHandles: Bool = false)
      async throws -> Amount {
        let request = GetMaxPeerPushDebitAmount(currency: currency, scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.rawAmount
    }
} // getMaxPeerPushAmountM
// - - - - - -
struct CheckPeerPushDebitResponse: Codable {
    let exchangeBaseUrl: String?                // API "2:0:1"
    let amountRaw: Amount
    let amountEffective: Amount
    let maxExpirationDate: Timestamp?           // API "2:0:1" TODO: limit expiration (30 days or 7 days)
}
fileprivate struct CheckPeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = CheckPeerPushDebitResponse
    func operation() -> String { "checkPeerPushDebit" }
    func args() -> Args { Args(amount: amount, restrictScope: scope, clientCancellationId: "cancel") }

    var amount: Amount
    var scope: ScopeInfo
    struct Args: Encodable {
        var amount: Amount
        var restrictScope: ScopeInfo
        var clientCancellationId: String?
    }
}
extension WalletModel {
    @MainActor          // M for MainActor
    func checkPeerPushDebitM(_ amount: Amount, scope: ScopeInfo, viewHandles: Bool = false)
      async throws -> CheckPeerPushDebitResponse {
        let request = CheckPeerPushDebit(amount: amount, scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // checkPeerPushDebitM
// - - - - - -
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
    func args() -> Args { Args(//exchangeBaseUrl: baseURL,
                                 restrictScope: scope,
                          partialContractTerms: terms) }

    var scope: ScopeInfo
//    var baseURL: String?
    var terms: PeerContractTerms
    struct Args: Encodable {
//        var exchangeBaseUrl: String?
        var restrictScope: ScopeInfo
        var partialContractTerms: PeerContractTerms
    }
}
extension WalletModel {
    @MainActor             // M for MainActor
    func initiatePeerPushDebitM(/*_ baseURL: String?,*/ scope: ScopeInfo, terms: PeerContractTerms, viewHandles: Bool = false)
    async throws -> InitiatePeerPushDebitResponse {
        let request = InitiatePeerPushDebit(//exchangeBaseUrl: baseURL,
                                                      scope: scope,
                                                      terms: terms)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // initiatePeerPushDebitM
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
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, scopeInfo: scopeInfo,
                                        amount: amount, clientCancellationId: "cancel") }

    var exchangeBaseUrl: String?
    var scopeInfo: ScopeInfo?
    var amount: Amount
    struct Args: Encodable {
        var exchangeBaseUrl: String?
        var scopeInfo: ScopeInfo?
        var amount: Amount
        var clientCancellationId: String?
    }
}
extension WalletModel {
    @MainActor           // M for MainActor
    func checkPeerPullCreditM(_ exchangeBaseUrl: String?, amount: Amount,
                                    viewHandles: Bool = false)
      async throws -> CheckPeerPullCreditResponse {
        let request = CheckPeerPullCredit(exchangeBaseUrl: exchangeBaseUrl,
                                                   amount: amount)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // checkPeerPullCreditM
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
    @MainActor
    func initiatePeerPullCreditM(_ baseURL: String?, terms: PeerContractTerms, viewHandles: Bool = false)  // M for MainActor
      async throws -> InitiatePeerPullCreditResponse {
        let request = InitiatePeerPullCredit(exchangeBaseUrl: baseURL,
                                        partialContractTerms: terms)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // initiatePeerPullCreditM
// MARK: - PeerPushCredit
/// Prepare an incoming peer push payment, receive coins
struct PreparePeerPushCreditResponse: Codable {
    let contractTerms: PeerContractTerms
    let amountRaw: Amount
    let amountEffective: Amount
    let exchangeBaseUrl: String
    // the dialog transaction is already created in the local DB - must either accept or delete
    let transactionId: String
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
    @MainActor
    func preparePeerPushCreditM(_ talerUri: String, viewHandles: Bool = false)       // M for MainActor
      async throws -> PreparePeerPushCreditResponse {
        let request = PreparePeerPushCredit(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // preparePeerPushCreditM
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
    @MainActor
    func acceptPeerPushCreditM(_ transactionId: String, viewHandles: Bool = false)       // M for MainActor
      async throws -> Decodable {
        let request = AcceptPeerPushCredit(transactionId: transactionId)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // acceptPeerPushCreditM
// MARK: - PeerPullDebit
/// Prepare an incoming peer push request(invoice), pay coins
struct PreparePeerPullDebitResponse: Codable {
    let contractTerms: PeerContractTerms
    let amountRaw: Amount
    let amountEffective: Amount
    // the dialog transaction is already created in the local DB - must either accept or delete
    let transactionId: String
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
    @MainActor
    func preparePeerPullDebitM(_ talerUri: String, viewHandles: Bool = false)       // M for MainActor
      async throws -> PreparePeerPullDebitResponse {
        let request = PreparePeerPullDebit(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // preparePeerPullDebitM
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
    @MainActor
    func confirmPeerPullDebitM(_ transactionId: String, viewHandles: Bool = false)       // M for MainActor
      async throws -> Decodable {
        let request = ConfirmPeerPullDebit(transactionId: transactionId)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
} // confirmPeerPullDebitM
