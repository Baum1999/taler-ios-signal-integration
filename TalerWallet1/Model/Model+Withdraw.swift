/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
/// The result from getWithdrawalDetailsForUri
struct WithdrawUriInfoResponse: Decodable {
    var amount: Amount
    var defaultExchangeBaseUrl: String?             // TODO: might be nil ❗️Yikes
    var possibleExchanges: [ExchangeListItem]       // TODO: query these for fees?
}
struct ExchangeListItem: Codable, Hashable {
    var exchangeBaseUrl: String
    var currency: String
    var paytoUris: [String]

    public static func == (lhs: ExchangeListItem, rhs: ExchangeListItem) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl &&
        lhs.currency == rhs.currency &&
        lhs.paytoUris == rhs.paytoUris
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(exchangeBaseUrl)
        hasher.combine(currency)
        hasher.combine(paytoUris)
    }
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForURI: WalletBackendFormattedRequest {
    typealias Response = WithdrawUriInfoResponse
    func operation() -> String { return "getWithdrawalDetailsForUri" }
    func args() -> Args { return Args(talerWithdrawUri: talerWithdrawUri) }

    var talerWithdrawUri: String
    struct Args: Encodable {
        var talerWithdrawUri: String
    }
}
// MARK: -
/// The result from getWithdrawalDetailsForAmount
struct WithdrawalAmountDetails: Decodable {
    var tosAccepted: Bool               // Did the user accept the current version of the exchange's terms of service?
    var amountRaw: Amount               // Amount that the user will transfer to the exchange
    var amountEffective: Amount         // Amount that will be added to the user's wallet balance
    var paytoUris: [String]             // Ways to pay the exchange
    var ageRestrictionOptions: [Int]?   // Array of ages
    var numCoins: Int?                  // Number of coins this amountEffective will create
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForAmount: WalletBackendFormattedRequest {
    typealias Response = WithdrawalAmountDetails
    func operation() -> String { return "getWithdrawalDetailsForAmount" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount) }

    var exchangeBaseUrl: String
    var amount: Amount
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
}
// MARK: -
enum ExchangeTosStatus: String, Codable {
    case new = "new"
    case accepted = "accepted"
    case changed = "changed"
    case notFound = "not-found"
    case unknown = "unknown"
}
struct ExchangeTermsOfService: Decodable {
    var currentEtag: String
    var acceptedEtag: String?
    var tosStatus: ExchangeTosStatus
    var contentType: String
    var content: String
}
/// A request to query an exchange's terms of service.
fileprivate struct GetExchangeTermsOfService: WalletBackendFormattedRequest {
    typealias Response = ExchangeTermsOfService
    func operation() -> String { return "getExchangeTos" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, acceptedFormat: acceptedFormat) }

    var exchangeBaseUrl: String
    var acceptedFormat: [String]?
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var acceptedFormat: [String]?
    }
}
/// A request to mark an exchange's terms of service as accepted.
fileprivate struct SetExchangeTOSAccepted: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "setExchangeTosAccepted" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, etag: etag) }

    var exchangeBaseUrl: String
    var etag: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
        var etag: String
    }
}
// MARK: -
struct AcceptWithdrawalResponse: Decodable {
    var reservePub: String
    var confirmTransferUrl: String?
    var transactionId: String
}
/// A request to accept a bank-integrated withdrawl.
fileprivate struct AcceptBankIntegratedWithdrawal: WalletBackendFormattedRequest {
    typealias Response = AcceptWithdrawalResponse
    func operation() -> String { return "acceptBankIntegratedWithdrawal" }
    func args() -> Args { return Args(talerWithdrawUri: talerWithdrawUri, exchangeBaseUrl: exchangeBaseUrl) }

    var talerWithdrawUri: String
    var exchangeBaseUrl: String

    struct Args: Encodable {
        var talerWithdrawUri: String
        var exchangeBaseUrl: String
    }
}
// MARK: -
struct AcceptManualWithdrawalResult: Decodable {
    var reservePub: String
    var exchangePaytoUris: [String]
    var transactionId: String
}
/// A request to accept a manual withdrawl.
fileprivate struct AcceptManualWithdrawal: WalletBackendFormattedRequest {
    typealias Response = AcceptManualWithdrawalResult
    func operation() -> String { return "acceptManualWithdrawal" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount, restrictAge: restrictAge) }

    var exchangeBaseUrl: String
    var amount: Amount
    var restrictAge: Int?

    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
        var restrictAge: Int?
    }
}
// MARK: -
extension WalletModel {
    /// load withdrawal details. Networking involved
    @MainActor
    func loadWithdrawalDetailsForUriM(_ talerWithdrawUri: String)               // M for MainActor
      async throws -> WithdrawUriInfoResponse {
        let request = GetWithdrawalDetailsForURI(talerWithdrawUri: talerWithdrawUri)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor
    func loadWithdrawalDetailsForAmountM(_ exchangeBaseUrl: String, amount: Amount)  // M for MainActor
      async throws -> WithdrawalAmountDetails {
        let request = GetWithdrawalDetailsForAmount(exchangeBaseUrl: exchangeBaseUrl,
                                                             amount: amount)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor
    func loadExchangeTermsOfServiceM(_ exchangeBaseUrl: String, acceptedFormat: [String])             // M for MainActor
      async throws -> ExchangeTermsOfService {
        let request = GetExchangeTermsOfService(exchangeBaseUrl: exchangeBaseUrl, acceptedFormat: acceptedFormat)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor
    func setExchangeTOSAcceptedM(_ exchangeBaseUrl: String, etag: String)       // M for MainActor
      async throws -> Decodable {
        let request = SetExchangeTOSAccepted(exchangeBaseUrl: exchangeBaseUrl, etag: etag)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor
    func sendAcceptIntWithdrawalM(_ exchangeBaseUrl: String, withdrawURL: String)   // M for MainActor
      async throws -> AcceptWithdrawalResponse? {
        let request = AcceptBankIntegratedWithdrawal(talerWithdrawUri: withdrawURL, exchangeBaseUrl: exchangeBaseUrl)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor
    func sendAcceptManualWithdrawalM(_ exchangeBaseUrl: String, amount: Amount, restrictAge: Int?)   // M for MainActor
      async throws -> AcceptManualWithdrawalResult? {
        let request = AcceptManualWithdrawal(exchangeBaseUrl: exchangeBaseUrl, amount: amount, restrictAge: restrictAge)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
}
