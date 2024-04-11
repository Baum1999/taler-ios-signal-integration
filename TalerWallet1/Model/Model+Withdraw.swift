/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

enum AccountRestrictionType: String, Codable {
    case deny
    case regex
}

typealias HintDict = [String:String]

struct AccountRestriction: Codable, Hashable {
    var type: AccountRestrictionType
    var payto_regex: String?
    var human_hint: String?
    var human_hint_i18n: HintDict?
}
extension AccountRestriction: Identifiable {
    var id: AccountRestriction {self}
}

//struct TalerErrorDetail: Decodable {
//    var code: TalerErrorCode
//    var when: AbsoluteTime?
//    var hint: String?
////    [x: string]: unknown;
//}

struct WithdrawalExchangeAccountDetails: Decodable {
    var status: String                                          // "OK" or error - then conversionError
    var paytoUri: String
    var transferAmount: Amount?                                 // only if "OK"
    var bankLabel: String?                                      // only if wallet-core knows it
    var currencySpecification: CurrencySpecification?           // only if wallet-core knows it
    var creditRestrictions: [AccountRestriction]?               // only if restrictions apply
//    var conversionError: TalerErrorDetail?                    // only if error
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
/// The result from prepareWithdrawExchange
struct WithdrawExchangeResponse: Decodable {
    var exchangeBaseUrl: String
    var amount: Amount?
}
/// A request to get an exchange's withdrawal details.
fileprivate struct PrepareWithdrawExchange: WalletBackendFormattedRequest {
    typealias Response = WithdrawExchangeResponse
    func operation() -> String { "prepareWithdrawExchange" }
    func args() -> Args { Args(talerUri: talerUri) }

    var talerUri: String
    struct Args: Encodable {
        var talerUri: String
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
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount, clientCancellationId: cancellationId) }

    var exchangeBaseUrl: String
    var amount: Amount
    var cancellationId: String?
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
        var clientCancellationId: String?
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
    var tosAvailableLanguages: [String]
    var contentType: String
    var contentLanguage: String?
    var content: String
}
/// A request to query an exchange's terms of service.
fileprivate struct GetExchangeTermsOfService: WalletBackendFormattedRequest {
    typealias Response = ExchangeTermsOfService
    func operation() -> String { "getExchangeTos" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, acceptedFormat: acceptedFormat, acceptLanguage: acceptLanguage) }

    var exchangeBaseUrl: String
    var acceptedFormat: [String]?
    var acceptLanguage: String?
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var acceptedFormat: [String]?
        var acceptLanguage: String?
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
    /// load withdraw-exchange details. Networking involved
    @MainActor                    // M for MainActor
    func loadWithdrawalExchangeForUriM(_ talerUri: String)
      async throws -> WithdrawExchangeResponse {
        let request = PrepareWithdrawExchange(talerUri: talerUri)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    /// load withdrawal details. Networking involved
    @MainActor                  // M for MainActor
    func getWithdrawalDetailsForUriM(_ talerWithdrawUri: String)
      async throws -> WithdrawUriInfoResponse {
        let request = GetWithdrawalDetailsForURI(talerWithdrawUri: talerWithdrawUri)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor                     // M for MainActor
    func getWithdrawalDetailsForAmountM(_ exchangeBaseUrl: String, amount: Amount, cancellationId: String? = nil)
      async throws -> WithdrawalAmountDetails {
        let request = GetWithdrawalDetailsForAmount(exchangeBaseUrl: exchangeBaseUrl,
                                                             amount: amount,
                                                     cancellationId: cancellationId)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor                  // M for MainActor
    func loadExchangeTermsOfServiceM(_ exchangeBaseUrl: String, acceptedFormat: [String], acceptLanguage: String)
      async throws -> ExchangeTermsOfService {
        let request = GetExchangeTermsOfService(exchangeBaseUrl: exchangeBaseUrl,
                                                 acceptedFormat: acceptedFormat,
                                                 acceptLanguage: acceptLanguage)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor              // M for MainActor
    func setExchangeTOSAcceptedM(_ exchangeBaseUrl: String, etag: String)
      async throws -> Decodable {
        let request = SetExchangeTOSAccepted(exchangeBaseUrl: exchangeBaseUrl, etag: etag)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor               // M for MainActor
    func sendAcceptIntWithdrawalM(_ exchangeBaseUrl: String, withdrawURL: String)
      async throws -> AcceptWithdrawalResponse? {
        let request = AcceptBankIntegratedWithdrawal(talerWithdrawUri: withdrawURL, exchangeBaseUrl: exchangeBaseUrl)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
    @MainActor                  // M for MainActor
    func sendAcceptManualWithdrawalM(_ exchangeBaseUrl: String, amount: Amount, restrictAge: Int?)
      async throws -> AcceptManualWithdrawalResult? {
        let request = AcceptManualWithdrawal(exchangeBaseUrl: exchangeBaseUrl, amount: amount, restrictAge: restrictAge)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }
}
