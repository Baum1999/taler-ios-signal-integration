/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

enum AccountRestrictionType: String, Decodable {
    case deny
    case regex
}
struct AccountRestriction: Decodable {
    var type: AccountRestrictionType
    var payto_regex: String?
    var human_hint: String?
    var human_hint_i18n: String?
}
struct WithdrawalExchangeAccountDetails: Decodable {
    var bankName: String?
    var paytoUri: String
    var transferAmount: Amount
    var currencySpecification: CurrencySpecification?
    var creditRestrictions: [AccountRestriction]?
}
// MARK: -
/// The result from getWithdrawalDetailsForUri
struct WithdrawUriInfoResponse: Decodable {
    var amount: Amount
    var defaultExchangeBaseUrl: String?
    var possibleExchanges: [Exchange]       // TODO: query these for fees?
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForURI: WalletBackendFormattedRequest {
    typealias Response = WithdrawUriInfoResponse
    func operation() -> String { "getWithdrawalDetailsForUri" }
    func args() -> Args { Args(talerWithdrawUri: talerWithdrawUri) }

    var talerWithdrawUri: String
    struct Args: Encodable {
        var talerWithdrawUri: String
    }
}
// MARK: -
/// The result from getWithdrawalDetailsForAmount
struct WithdrawalAmountDetails: Decodable {
    var amountRaw: Amount               // Amount that the user will transfer to the exchange
    var amountEffective: Amount         // Amount that will be added to the user's wallet balance
    var numCoins: Int?                  // Number of coins this amountEffective will create
    var withdrawalAccountsList: [WithdrawalExchangeAccountDetails]?
    var ageRestrictionOptions: [Int]?   // Array of ages
    var scopeInfo: ScopeInfo
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForAmount: WalletBackendFormattedRequest {
    typealias Response = WithdrawalAmountDetails
    func operation() -> String { "getWithdrawalDetailsForAmount" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount) }

    var exchangeBaseUrl: String
    var amount: Amount
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
}
// MARK: -
enum ExchangeTosStatus: String, Codable {
    case pending
    case proposed
    case accepted
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
    func operation() -> String { "getExchangeTos" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, acceptedFormat: acceptedFormat) }

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
    func operation() -> String { "setExchangeTosAccepted" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, etag: etag) }

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
    func operation() -> String { "acceptBankIntegratedWithdrawal" }
    func args() -> Args { Args(talerWithdrawUri: talerWithdrawUri, exchangeBaseUrl: exchangeBaseUrl) }

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
    var withdrawalAccountsList: [WithdrawalExchangeAccountDetails]
    var transactionId: String
}
/// A request to accept a manual withdrawl.
fileprivate struct AcceptManualWithdrawal: WalletBackendFormattedRequest {
    typealias Response = AcceptManualWithdrawalResult
    func operation() -> String { "acceptManualWithdrawal" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount, restrictAge: restrictAge) }

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
