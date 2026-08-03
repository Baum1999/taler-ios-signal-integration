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

enum TransferType: String, Codable {
    case payto
    case chQrBill = "ch-qr-bill"
    case uri
}

struct QrCodeSpec: Codable, Hashable {
    var type: String
    var qrContent: String
}

struct TransferOption: Codable, Hashable {
    var type: TransferType
    var uri: String?                                            // only if type == uri
    var paytoUri: String?                                       // only if type == payto
    var qrReferenceNumber: String?
    var qrCodes: [QrCodeSpec]?
}

struct ExchangeAccountDetails: Decodable, Hashable {
    var status: String                                          // "OK" or "error" - then conversionError
    var paytoUri: String
    var transferAmount: Amount?                                 // only if "OK"
    var transferOptions: [TransferOption]?
    var transferExpiry: Timestamp?
    var bankLabel: String?                                      // only if wallet-core knows it
    var currencySpecification: CurrencySpecification?           // only if wallet-core knows it
    var creditRestrictions: [AccountRestriction]?               // only if restrictions apply
//    var conversionError: TalerErrorDetail?                    // only if error
    var scope: ScopeInfo?                                       // for Deposit
}
// MARK: -
enum WithdrawalOperationStatus: String, Codable {
    case pending
    case selected
    case aborted
    case confirmed
}
/// The result from prepareBankIntegratedWithdrawal
struct WithdrawUriInfoResponse: Decodable {
    var operationId: String
    var status: WithdrawalOperationStatus   // pending, selected, aborted, confirmed
    var confirmTransferUrl: String?
    var currency: String                    // use this if amount=nil
    var amount: Amount?                     // if nil then either ask User (editableAmount=true), or it's cash2ecash (editableAmount=false)
    var editableAmount: Bool                // if true then ask User
    var maxAmount: Amount?                  // limit how much the user may withdraw
    var wireFee: Amount?
    var defaultExchangeBaseUrl: String?     // if nil then use possibleExchanges
    var editableExchange: Bool              // TODO: what for?
    var possibleExchanges: [Exchange]       // TODO: query these for fees?
}

struct PrepareBankIntegratedWithdrawalResponse: Decodable {
    var transactionId: String
    var info: WithdrawUriInfoResponse
}

/// A request to get an exchange's withdrawal details.
fileprivate struct PrepareBankIntegratedWithdrawal: WalletBackendFormattedRequest {
    typealias Response = PrepareBankIntegratedWithdrawalResponse
    var operation: String { "prepareBankIntegratedWithdrawal" }
    func args() -> Args { Args(talerWithdrawUri: talerUri,
                                  progressToken: talerUri) }    // TODO: lastPathComponent
    var talerUri: String
    struct Args: Encodable {
        var talerWithdrawUri: String
        var progressToken: String?
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
    var operation: String { "prepareWithdrawExchange" }
    func args() -> Args { Args(talerUri: talerUri,
                          progressToken: talerUri) }
    var talerUri: String
    struct Args: Encodable {
        var talerUri: String
        var progressToken: String?
    }
}
// MARK: -
/// The result from getWithdrawalDetailsForAmount
struct WithdrawalDetailsForAmount: Decodable {
    var exchangeBaseUrl: String
    var amountRaw: Amount               // Amount that the user will transfer to the exchange
    var amountEffective: Amount         // Amount that will be added to the user's wallet balance
    var numCoins: Int?                  // Number of coins this amountEffective will create
    var withdrawalAccountsList: [ExchangeAccountDetails]?
    var ageRestrictionOptions: [Int]?   // Array of ages
    var scopeInfo: ScopeInfo
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForAmount: WalletBackendFormattedRequest {
    typealias Response = WithdrawalDetailsForAmount
    var operation: String { "getWithdrawalDetailsForAmount" }
    func args() -> Args { Args(amount: amount,
                      exchangeBaseUrl: baseUrl,
                        restrictScope: scope,
                 clientCancellationId: "cancel") }
    var amount: Amount
    var baseUrl: String?
    var scope: ScopeInfo?
    struct Args: Encodable {
        var amount: Amount
        var exchangeBaseUrl: String?            // needed for b-i-withdrawals
        var restrictScope: ScopeInfo?           // only if exchangeBaseUrl is nil
        var clientCancellationId: String?
    }
}
// MARK: -
enum ExchangeTosStatus: String, Codable {
    case missingTos = "missing-tos"
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
    var operation: String { "getExchangeTos" }
    func args() -> Args { Args(exchangeBaseUrl: baseUrl,
                                acceptedFormat: acceptedFormat,
                                acceptLanguage: acceptLanguage,
                                 progressToken: baseUrl) }
    var baseUrl: String
    var acceptedFormat: [String]?
    var acceptLanguage: String?
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var acceptedFormat: [String]?
        var acceptLanguage: String?
        var progressToken: String
    }
}
/// A request to mark an exchange's terms of service as accepted.
fileprivate struct SetExchangeTOSAccepted: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "setExchangeTosAccepted" }
    func args() -> Args { Args(exchangeBaseUrl: baseUrl) }

    var baseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}
// MARK: -
struct AcceptWithdrawalResponse: Decodable {
    var transactionId: String
    var confirmTransferUrl: String?
//    var reservePub: String
}
/// A request to accept a bank-integrated withdrawl.
fileprivate struct AcceptBankIntegratedWithdrawal: WalletBackendFormattedRequest {
    typealias Response = AcceptWithdrawalResponse
    var operation: String { "acceptBankIntegratedWithdrawal" }
    func args() -> Args { Args(talerWithdrawUri: talerUri, exchangeBaseUrl: baseUrl,
                               amount: amount, restrictAge: restrictAge, progressToken: talerUri) }

    var talerUri: String
    var baseUrl: String
    var amount: Amount?
    var restrictAge: Int?

    struct Args: Encodable {
        var talerWithdrawUri: String
        var exchangeBaseUrl: String
        var amount: Amount?
        var restrictAge: Int?
        var progressToken: String
    }
}
// MARK: -
struct AcceptManualWithdrawalResult: Decodable {
    var reservePub: String
    var withdrawalAccountsList: [ExchangeAccountDetails]
    var transactionId: String
}
/// A request to accept a manual withdrawl.
fileprivate struct AcceptManualWithdrawal: WalletBackendFormattedRequest {
    typealias Response = AcceptManualWithdrawalResult
    var operation: String { "acceptManualWithdrawal" }
    func args() -> Args { Args(amount: amount, exchangeBaseUrl: baseUrl, restrictAge: restrictAge) }

    var amount: Amount
    var baseUrl: String
    var restrictAge: Int?

    struct Args: Encodable {
        var amount: Amount
        var exchangeBaseUrl: String
        var restrictAge: Int?
    }
}
// MARK: -
extension WalletModel {
    /// load withdraw-exchange details. Networking involved
    nonisolated func prepareWithdrawExchange(_ talerUri: String,
                                            viewHandles: Bool = false)
      async throws -> WithdrawExchangeResponse {
        let request = PrepareWithdrawExchange(talerUri: talerUri)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = talerUri
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    /// load withdrawal details. Networking involved
    nonisolated func prepareBankIntegratedWithdrawal(_ talerUri: String,
                                               viewHandles: Bool = false)
      async throws -> PrepareBankIntegratedWithdrawalResponse {
        let request = PrepareBankIntegratedWithdrawal(talerUri: talerUri)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = talerUri
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func getWithdrawalDetailsForAmount(_ amount: Amount,
                                                    baseUrl: String?,
                                                      scope: ScopeInfo?,
                                                viewHandles: Bool = false)
      async throws -> WithdrawalDetailsForAmount {
        let request = GetWithdrawalDetailsForAmount(amount: amount, baseUrl: baseUrl, scope: scope)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func getExchangeTos(_ baseUrl: String,
                               acceptedFormat: [String],
                               acceptLanguage: String,
                                  viewHandles: Bool = false)
      async throws -> ExchangeTermsOfService {
        let request = GetExchangeTermsOfService(baseUrl: baseUrl,
                                         acceptedFormat: acceptedFormat,
                                         acceptLanguage: acceptLanguage)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = baseUrl
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func setExchangeTOSAccepted(_ baseUrl: String,
                                          viewHandles: Bool = false)
      async throws -> Decodable {
        let request = SetExchangeTOSAccepted(baseUrl: baseUrl)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func acceptBankIntWithdrawal(_ baseUrl: String,
                                           withdrawURL: String,
                                                amount: Amount?,
                                           restrictAge: Int?,
                                           viewHandles: Bool = false)
      async throws -> AcceptWithdrawalResponse? {
        let request = AcceptBankIntegratedWithdrawal(talerUri: withdrawURL, baseUrl: baseUrl,
                                                       amount: amount, restrictAge: restrictAge)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = withdrawURL
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    nonisolated func acceptManualWithdrawal(_ amount: Amount,
                                             baseUrl: String,
                                         restrictAge: Int?,
                                         viewHandles: Bool = false)
      async throws -> AcceptManualWithdrawalResult? {
        let request = AcceptManualWithdrawal(amount: amount, baseUrl: baseUrl, restrictAge: restrictAge)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
