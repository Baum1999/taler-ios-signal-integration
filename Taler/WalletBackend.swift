/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */

import Foundation
import iono
import taler_swift

enum WalletBackendResponseError: Error {
    case malformedResponse
}

protocol WalletBackendRequest {
    associatedtype Args: Encodable
    associatedtype Response: Decodable
    
    func operation() -> String
    func args() -> Args
    func success(result: Response)
    func error(_ err: WalletBackendResponseError)
}

fileprivate struct WalletBackendRequestData<T: WalletBackendRequest>: Encodable {
    var operation: String
    var id: UInt
    var args: T.Args
    
    init(request: T, id: UInt) {
        operation = request.operation()
        self.id = id
        args = request.args()
    }
}

fileprivate struct WalletBackendInitRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var persistentStoragePath: String
    }
    typealias Args = RequestArgs
    struct Response: Codable {
        struct SupportedProtocolVersions: Codable {
            var exchange: String
            var merchant: String
        }
        var supportedProtocolVersions: SupportedProtocolVersions
        enum CodingKeys: String, CodingKey {
            case supportedProtocolVersions = "supported_protocol_versions"
        }
    }
    private var requestArgs: RequestArgs
    private let success: () -> Void
    
    init(persistentStoragePath: String, onSuccess: @escaping () -> Void) {
        requestArgs = RequestArgs(persistentStoragePath: persistentStoragePath)
        self.success = onSuccess
    }
    
    func operation() -> String {
        return "init"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

/**
    An balance on a wallet.
 */
struct Balance: Decodable {
    var available: Amount
    var pendingIncoming: Amount
    var pendingOutgoing: Amount
    var requiresUserInput: Bool
}

/**
    A request to get the balances held in the wallet.
 */
class WalletBackendGetBalancesRequest: WalletBackendRequest {
    struct BalancesResponse: Decodable {
        var balances: [Balance]
    }
    struct RequestArgs: Encodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = BalancesResponse
    private var requestArgs: RequestArgs
    private let success: ([Balance]) -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping ([Balance]) -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs()
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getBalances"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success(result.balances)
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A billing or mailing location.
 */
struct Location: Codable {
    var country: String?
    var country_subdivision: String?
    var district: String?
    var town: String?
    var town_location: String?
    var post_code: String?
    var street: String?
    var building_name: String?
    var building_number: String?
    var address_lines: [String]?
}

/**
    Information identifying a merchant.
 */
struct Merchant: Codable {
    var name: String
    var address: Location?
    var jurisdiction: Location?
}

/**
    A tax made on a payment.
 */
struct Tax: Codable {
    var name: String
    var tax: Amount
}

/**
    A product being purchased from a merchant.
 */
struct Product: Codable {
    var product_id: String?
    var description: String
    // description_i18n?
    var quantity: Int
    var unit: String
    var price: Amount?
    var image: String // URL to a product image
    var taxes: [Tax]?
    var delivery_date: Timestamp?
}

/**
    Brief information about an order.
 */
struct OrderShortInfo: Codable {
    var orderId: String
    var merchant: Merchant
    var summary: String
    // summary_i18n?
    var products: [Product]
    var fulfillmentUrl: String?
    var fulfillmentMessage: String?
    // fulfillmentMessage_i18n?
}

enum TransactionTypeError: Error {
    case unknownTypeError
}

/**
    Different types of transactions.
 */
enum TransactionType: Codable {
    case withdrawal
    case payment
    case refund
    case tip
    case refresh
    
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let str = try value.decode(String.self)
        let codingNames = [
            "TransactionWithdrawal" : TransactionType.withdrawal,
            "TransactionPayment" : TransactionType.payment,
            "TransactionRefund" : TransactionType.refund,
            "TransactionTip" : TransactionType.tip,
            "TransactionRefresh" : TransactionType.refresh
        ]
        if let type = codingNames[str] {
            self = type
        } else {
            throw TransactionTypeError.unknownTypeError
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .withdrawal:
            try value.encode("TransactionWithdrawal")
        case .payment:
            try value.encode("TransactionPayment")
        case .refund:
            try value.encode("TransactionRefund")
        case .tip:
            try value.encode("TransactionTip")
        case .refresh:
            try value.encode("TransactionRefresh")
        }
    }
}

/**
    An error associated with a transaction.
 */
struct TransactionError: Codable {
    var ec: Int
    var hint: String?
    //var details: Any?
}

/**
    A wallet transaction.
 */
struct Transaction: Codable {
    var transactionId: String
    var type: TransactionType
    var timestamp: Timestamp
    var pending: Bool
    var error: TransactionError?
    var amountRaw: Amount
    var amountEffective: Amount
}

/**
    A request to get the transactions in the wallet's history.
 */
class WalletBackendGetTransactionsRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var currency: String?
        var search: String?
    }
    struct TransactionsResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = TransactionsResponse
    private var requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(currency: nil, search: nil)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    init(filterCurrency: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(currency: filterCurrency, search: nil)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    init(searchString: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(currency: nil, search: searchString)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    init(filterCurrency: String, searchString: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(currency: filterCurrency, search: searchString)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getTransactions"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to delete a wallet transaction by ID.
 */
class WalletBackendDeleteTransactionRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var transactionId: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private var requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(transactionID: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(transactionId: transactionID)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "deleteTransaction"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to process a refund.
 */
class WalletBackendApplyRefundRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var talerRefundUri: String
    }
    struct RequestResponse: Decodable {
        var contractTermsHash: String
        var amountEffectivePaid: Amount
        var amountRefundGranted: Amount
        var amountRefundGone: Amount
        var pendingAtExchange: Bool
        var info: OrderShortInfo
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: (RequestResponse) -> Void
    private let failure: () -> Void
    
    init(refundURI: String, onSuccess: @escaping (RequestResponse) -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(talerRefundUri: refundURI)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "applyRefund"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success(result)
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to list exchanges.
 */
class WalletBackendListExchanges: WalletBackendRequest {
    struct RequestArgs: Encodable {
        
    }
    struct ExchangeListItem: Decodable {
        var exchangeBaseUrl: String
        var currency: String
        var paytoUris: [String]
    }
    struct RequestResponse: Decodable {
        var exchanges: [ExchangeListItem]
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let success: ([ExchangeListItem]) -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping ([ExchangeListItem]) -> Void, onFailure: @escaping () -> Void) {
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "listExchanges"
    }
    
    func args() -> RequestArgs {
        return RequestArgs()
    }
    
    func success(result: RequestResponse) {
        self.success(result.exchanges)
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to add an exchange.
 */
class WalletBackendAddRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "addRequest"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to force update an exchange.
 */
class WalletBackendForceUpdateRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "addRequest"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to query an exchange's terms of service.
 */
class WalletBackendGetExchangeTermsOfService: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
    }
    struct RequestResponse: Decodable {
        var tos: String
        var currentEtag: String
        var acceptedEtag: String
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getExchangeTos"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to mark an exchange's terms of service as accepted.
 */
class WalletBackendSetExchangeTermsOfServiceAccepted: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
        var acceptedEtag: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, acceptedEtag: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL, acceptedEtag: acceptedEtag)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "setExchangeTosAccepted"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

struct ExchangeListItem: Codable {
    var exchangeBaseUrl: String
    var currency: String
    var paytoUris: [String]
}

/**
    A request to get an exchange's withdrawal details.
 */
class WalletBackendGetWithdrawalDetailsForURIRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var talerWithdrawUri: String
    }
    struct RequestResponse: Decodable {
        var amount: Amount
        var defaultExchangeBaseUrl: String?
        var possibleExchanges: [ExchangeListItem]
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(talerWithdrawUri: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(talerWithdrawUri: talerWithdrawUri)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getWithdrawalDetailsForUri"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to get an exchange's withdrawal details.
 */
class WalletBackendGetWithdrawalDetailsForAmountRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
    struct RequestResponse: Decodable {
        var tosAccepted: Bool
        var amountRaw: Amount
        var amountEffective: Amount
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, amount: Amount, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL, amount: amount)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getWithdrawalDetailsForAmount"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to accept a bank-integrated withdrawl.
 */
class WalletBackendAcceptBankIntegratedWithdrawalRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var talerWithdrawUri: String
        var exchangeBaseUrl: String
    }
    struct RequestResponse: Decodable {
        var bankConfirmationUrl: String?
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(talerWithdrawURI: String, exchangeBaseURL: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(talerWithdrawUri: talerWithdrawURI, exchangeBaseUrl: exchangeBaseURL)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "acceptWithdrawal"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to accept a manual withdrawl.
 */
class WalletBackendAcceptManualWithdrawalRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
    struct RequestResponse: Decodable {
        var exchangePaytoUris: [String]
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(exchangeBaseURL: String, amount: Amount, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(exchangeBaseUrl: exchangeBaseURL, amount: amount)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "acceptManualWithdrawal"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to deposit funds.
 */
class WalletBackendCreateDepositGroupRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var depositPayToUri: String
        var amount: Amount
    }
    struct RequestResponse: Decodable {
        var depositGroupId: String
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(depositPayToUri: String, amount: Amount, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(depositPayToUri: depositPayToUri, amount: amount)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "createDepositGroup"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to get information about a payment request.
 */
class WalletBackendPreparePayRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var talerPayUri: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(talerPayUri: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(talerPayUri: talerPayUri)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "preparePay"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to confirm a payment.
 */
class WalletBackendConfirmPayRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var proposalId: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(proposalId: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(proposalId: proposalId)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "abortFailedPayWithRefund"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to prepare a tip.
 */
class WalletBackendPrepareTipRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var talerTipUri: String
    }
    struct RequestResponse: Decodable {
        var walletTipId: String
        var accepted: Bool
        var tipAmountRaw: Amount
        var tipAmountEffective: Amount
        var exchangeBaseUrl: String
        var expirationTimestamp: Timestamp
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(talerTipURI: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(talerTipUri: talerTipURI)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "prepareTip"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to accept a tip.
 */
class WalletBackendAcceptTipRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var walletTipId: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(walletTipId: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(walletTipId: walletTipId)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "acceptTip"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to abort a failed payment.
 */
class WalletBackendAbortFailedPaymentRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var proposalId: String
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(proposalId: String, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(proposalId: proposalId)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "confirmPay"
    }
    
    func args() -> RequestArgs {
        return requestArgs
    }
    
    func success(result: RequestResponse) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to withdraw a balance from the TESTKUDOS environment.
 */
class WalletBackendWithdrawTestkudosRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let success: () -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "withdrawTestkudos"
    }
    
    func args() -> Args {
        return RequestArgs()
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to add a test balance to the wallet.
 */
class WalletBackendWithdrawTestBalance: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var amount: Amount
        var bankBaseUrl: String
        var exchangeBaseUrl: String
    }
    typealias Args = RequestArgs
    typealias Response = String
    private var requestArgs: RequestArgs
    
    init(amount: Amount, bankBaseUrl: String, exchangeBaseUrl: String) {
        requestArgs = RequestArgs(amount: amount, bankBaseUrl: bankBaseUrl, exchangeBaseUrl: exchangeBaseUrl)
    }
    
    func operation() -> String {
        return "withdrawTestBalance"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

struct IntegrationTestArgs: Codable {
    var exchangeBaseUrl: String
    var bankBaseUrl: String
    var merchantBaseUrl: String
    var merchantApiKey: String
    var amountToWithdraw: String
    var amountToSpend: String
}

/**
    A request to run a basic integration test.
 */
class WalletBackendRunIntegrationTestRequest: WalletBackendRequest {
    struct RequestResponse: Decodable {
        
    }
    typealias Args = IntegrationTestArgs
    typealias Response = RequestResponse
    private let requestArgs: IntegrationTestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(args: IntegrationTestArgs, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = args
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "runIntegrationTest"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

struct TestPayArgs: Codable {
    var merchantBaseUrl: String
    var merchantApiKey: String
    var amount: String
    var summary: String
}

/**
    A request to make a test payment.
 */
class WalletBackendTestPayRequest: WalletBackendRequest {
    struct RequestResponse: Decodable {
        
    }
    typealias Args = TestPayArgs
    typealias Response = RequestResponse
    private let requestArgs: TestPayArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(args: TestPayArgs, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = args
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "testPay"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

struct Coin: Codable {
    var denom_pub: String
    var denom_pub_hash: String
    var denom_value: String
    var coin_pub: String
    var exchange_base_url: String
    var remaining_value: String
    var refresh_parent_coin_pub: String
    var withdrawal_reserve_pub: String
    var coin_suspended: Bool
}

/**
    A request to dump all coins to JSON.
 */
class WalletBackendDumpCoinsRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        
    }
    struct RequestResponse: Decodable {
        var coins: [Coin]
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let success: () -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "dumpCoins"
    }
    
    func args() -> Args {
        return RequestArgs()
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

/**
    A request to suspend or unsuspend a coin.
 */
class WalletBackendSuspendCoinRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var coinPub: String
        var suspended: Bool
    }
    struct RequestResponse: Decodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = RequestResponse
    private let requestArgs: RequestArgs
    private let success: () -> Void
    private let failure: () -> Void
    
    init(coinPub: String, suspended: Bool, onSuccess: @escaping () -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs(coinPub: coinPub, suspended: suspended)
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "setCoinSuspended"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        self.failure()
    }
}

enum WalletBackendError: Error {
    case initializationError
    case serializationError
    case deserializationError
}

class WalletBackend: IonoMessageHandler {
    private var iono: Iono
    private var requestsMade: UInt
    private var backendReady: Bool
    private var backendReadyCondition: NSCondition
    private struct RequestDetail {
        let decodeSuccess: (Data) -> Void
        //let handleError: (Data) -> Void
    }
    private var requests: [UInt : RequestDetail] = [:]
    
    init() throws {
        iono = Iono()
        requestsMade = 0
        self.backendReady = false
        self.backendReadyCondition = NSCondition()
        
        iono.messageHandler = self
        
        let js_path = URL(fileURLWithPath: Bundle.main.path(forResource: "taler-wallet-embedded", ofType: "js")!)
        do {
            let js = try String(contentsOf: js_path, encoding: .utf8)
            iono.putModuleCode(modName: "@gnu-taler/taler-wallet-embedded", code: js)
            iono.evalNodeCode(source: "require('iono');")
            iono.evalNodeCode(source: "tw = require('@gnu-taler/taler-wallet-embedded');")
            iono.evalNodeCode(source: "tw.installNativeWalletListener();")
        } catch {
            throw WalletBackendError.initializationError
        }
        
        // Send the init message
        let documentUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if (documentUrls.count > 0) {
            var storageDir = documentUrls[0]
            storageDir.appendPathComponent("talerwalletdb-v30", isDirectory: false)
            storageDir.appendPathExtension("json")
            try! sendRequest(request: WalletBackendInitRequest(persistentStoragePath: storageDir.path, onSuccess: {
                self.backendReady = true
                self.backendReadyCondition.broadcast()
            }))
        }
        
        waitUntilReady()
    }
    
    func waitUntilReady() {
        backendReadyCondition.lock()
        while (!self.backendReady) {
            backendReadyCondition.wait()
        }
        backendReadyCondition.unlock()
    }
    
    func handleMessage(message: String) {
        print(message)
        do {
            guard let messageData = message.data(using: .utf8) else { throw WalletBackendError.deserializationError }
            let data = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [String : Any]
            if let responseData = data {
                let type = (responseData["type"] as? String) ?? ""
                if type == "response" {
                    guard let id = responseData["id"] as? UInt else { /* TODO: error. */ return }
                    guard let request = requests[id] else { /* TODO: error. */ return }
                    request.decodeSuccess(messageData)
                    requests[id] = nil
                } else if type == "tunnelHttp" {
                    
                } else if type == "notification" {
                    
                } else if type == "error" {
                    guard let id = responseData["id"] as? UInt else { /* TODO: error. */ return }
                    guard let request = requests[id] else { /* TODO: error. */ return }
                    //request.handleError(messageData)
                    requests[id] = nil
                } else {
                    /* TODO: unknown response type. */
                }
            }
        } catch {
            
        }
    }
    
    private struct FullResponse<T: WalletBackendRequest>: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let result: T.Response
    }
    
    /*private struct FullError: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let error: WalletErrorDetail
    }*/
    
    func sendRequest<T: WalletBackendRequest>(request: T) throws {
        let data = WalletBackendRequestData<T>(request: request, id: requestsMade)
        requestsMade += 1
        let decodeSuccess = { (data: Data) -> Void in
            do {
                let decoded = try JSONDecoder().decode(FullResponse<T>.self, from: data)
                request.success(result: decoded.result)
            } catch {
                
            }
        }
        
        /* Encode the request and send it to the backend. */
        do {
            let encoded = try JSONEncoder().encode(data)
            guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
            let detail = RequestDetail(decodeSuccess: decodeSuccess)
            requests[data.id] = detail
            iono.sendMessage(message: jsonString)
        } catch {
            throw WalletBackendError.serializationError
        }
    }
}
