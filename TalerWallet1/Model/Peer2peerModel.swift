/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

class Peer2peerModel: WalletModel {
    override init(_ symbol: Int = -1) {     // init with 0 to disable logging for this class
        super.init(symbol)
    }
}
// MARK: - PeerContractTerms
struct PeerContractTerms: Codable {
    let amount: Amount
    let summary: String
    let purse_expiration: Timestamp
}
// MARK: -
/// The result from CheckPeerPushDebit
struct CheckPeerPushDebitResponse: Codable {
    let exchangeBaseUrl: String
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
    let amountEffective: Amount
    let amountRaw: Amount
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
struct PeerPushResponse: Codable {
    let contractPriv: String
    let mergePriv: String
    let pursePub: String
    let exchangeBaseUrl: String
    let talerUri: String
    let transactionId: String
}
/// A request to send coins to another wallet.
fileprivate struct InitiatePeerPushDebit: WalletBackendFormattedRequest {
    typealias Response = PeerPushResponse
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
extension Peer2peerModel {
    /// query exchange for fees (sending coins). Networking involved
    @MainActor
    func checkPeerPushDebitM(_ amount: Amount)       // M for MainActor
      async throws -> CheckPeerPushDebitResponse {
          let request = CheckPeerPushDebit(amount: amount)
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
    /// generate peer-push. Networking involved
    @MainActor
    func initiatePeerPushDebitM(_ baseURL: String, terms: PeerContractTerms)       // M for MainActor
      async throws -> PeerPushResponse {
        let request = InitiatePeerPushDebit(exchangeBaseUrl: baseURL,
                                       partialContractTerms: terms)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
}

// MARK: -
extension Peer2peerModel {
    private static var models: [Peer2peerModel] = []     // a list of models even though I currently need only one

    static func model() -> Peer2peerModel {
        if Peer2peerModel.models.count > 0 {
            let model = Peer2peerModel.models[0]
            return model
        } else {        // new model
            let model = Peer2peerModel()
            Peer2peerModel.models.append(model)
            return model
        }
    }
}
