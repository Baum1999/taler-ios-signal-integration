/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: - PeerContractTerms
struct PeerContractTerms: Codable {
    let amount: Amount
    let summary: String
    let purse_expiration: Timestamp
}
// MARK: -
/// The result from CheckPeerPushDebit
struct CheckPeerPushDebitResponse: Codable {
    let exchangeBaseUrl: String?
    let amountRaw: Amount
    let amountEffective: Amount
    let maxExpirationDate: Timestamp?          // TODO: limit expiration (30 days or 7 days)
}
/// A request to check fees before sending coins to another wallet.
fileprivate struct CheckPeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = CheckPeerPushDebitResponse
    func operation() -> String { return "checkPeerPushDebit" }
    func args() -> Args { return Args(amount: amount) }

    var amount: Amount
    struct Args: Encodable {
        var amount: Amount
    }
}
// MARK: -
/// The result from CheckPeerPullCredit
struct CheckPeerPullCreditResponse: Codable {
    let scopeInfo: ScopeInfo?
    let exchangeBaseUrl: String?
    let amountRaw: Amount
    let amountEffective: Amount
    var numCoins: Int?                  // Number of coins this amountEffective will create
}
/// A request to check fees before invoicing another wallet.
fileprivate struct CheckPeerPullCredit: WalletBackendFormattedRequest {
    typealias Response = CheckPeerPullCreditResponse
    func operation() -> String { return "checkPeerPullCredit" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, scopeInfo: scopeInfo, amount: amount) }

    var exchangeBaseUrl: String?
    var scopeInfo: ScopeInfo?
    var amount: Amount
    struct Args: Encodable {
        var exchangeBaseUrl: String?
        var scopeInfo: ScopeInfo?
        var amount: Amount
    }
}
// MARK: -
/// The result from InitiatePeerPushDebit
struct InitiatePeerPushDebitResponse: Codable {
    let contractPriv: String
    let mergePriv: String
    let pursePub: String
    let exchangeBaseUrl: String
    let talerUri: String
    let transactionId: String
}
/// A request to send coins to another wallet.
fileprivate struct InitiatePeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = InitiatePeerPushDebitResponse
    func operation() -> String { return "initiatePeerPushDebit" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl,
                                      partialContractTerms: partialContractTerms) }

    var exchangeBaseUrl: String?
    var partialContractTerms: PeerContractTerms
    struct Args: Encodable {
        var exchangeBaseUrl: String?
        var partialContractTerms: PeerContractTerms
    }
}
// MARK: -
struct PreparePeerPushCreditResponse: Codable {
    let contractTerms: PeerContractTerms
    let amountRaw: Amount
    let amountEffective: Amount
    let transactionId: String           // after scanning the transaction already is created in the local DB
}
/// A request to receive coins from another wallet.
fileprivate struct PreparePeerPushCredit: WalletBackendFormattedRequest {
    typealias Response = PreparePeerPushCreditResponse
    func operation() -> String { return "preparePeerPushCredit" }
    func args() -> Args { return Args(talerUri: talerUri) }

    var talerUri: String
    struct Args: Encodable {
        var talerUri: String
    }
}
// MARK: -
fileprivate struct ConfirmPeerPushCredit: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { return "confirmPeerPushCredit" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String
    struct Args: Encodable {
        var transactionId: String
    }
}
// MARK: -
/// The result from InitiatePeerPullCredit
struct InitiatePeerPullCreditResponse: Codable {
    let talerUri: String
    let transactionId: String
}
/// A request to send a payment request to another wallet.
fileprivate struct InitiatePeerPullCredit: WalletBackendFormattedRequest {
    typealias Response = InitiatePeerPullCreditResponse
    func operation() -> String { return "initiatePeerPullCredit" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl,
                                      partialContractTerms: partialContractTerms) }

    var exchangeBaseUrl: String?
    var partialContractTerms: PeerContractTerms
    struct Args: Encodable {
        var exchangeBaseUrl: String?
        var partialContractTerms: PeerContractTerms
    }
}
// MARK: -
extension WalletModel {
    /// query exchange for fees (sending coins). Networking involved
    @MainActor
    func checkPeerPushDebitM(_ amount: Amount)       // M for MainActor
      async throws -> CheckPeerPushDebitResponse {
          let request = CheckPeerPushDebit(amount: amount)
          let response = try await sendRequest(request, ASYNCDELAY)
          return response
    }
    /// generate peer-push. Networking involved
    @MainActor
    func initiatePeerPushDebitM(_ baseURL: String?, terms: PeerContractTerms)       // M for MainActor
      async throws -> InitiatePeerPushDebitResponse {
        let request = InitiatePeerPushDebit(exchangeBaseUrl: baseURL,
                                       partialContractTerms: terms)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }

    /// query exchange for fees (invoice coins). Networking involved
    @MainActor
    func checkPeerPullCreditM(_ amount: Amount, exchangeBaseUrl: String?)       // M for MainActor
      async throws -> CheckPeerPullCreditResponse {
        let request = CheckPeerPullCredit(exchangeBaseUrl: exchangeBaseUrl, amount: amount)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    /// generate peer-pull. Networking involved
    @MainActor
    func initiatePeerPullCreditM(_ baseURL: String?, terms: PeerContractTerms)       // M for MainActor
      async throws -> InitiatePeerPullCreditResponse {
        let request = InitiatePeerPullCredit(exchangeBaseUrl: baseURL,
                                        partialContractTerms: terms)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }

    /// prepare peer-pull. Networking involved
    @MainActor
    func preparePeerPushCreditM(_ talerUri: String)       // M for MainActor
      async throws -> PreparePeerPushCreditResponse {
        let request = PreparePeerPushCredit(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    /// confirm peer-pull. Networking involved
    @MainActor
    func confirmPeerPushCreditM(_ transactionId: String)       // M for MainActor
      async throws -> Decodable {
        let request = ConfirmPeerPushCredit(transactionId: transactionId)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
}
