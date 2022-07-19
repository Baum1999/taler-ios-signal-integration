/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
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
import AnyCodable

/// Information supplied by the backend describing an error.
struct WalletBackendResponseError: Decodable {
    /// Numeric error code defined defined in the GANA gnu-taler-error-codes registry.
    var talerErrorCode: Int
    
    /// English description of the error code.
    var talerErrorHint: String
    
    /// English diagnostic message that can give details for the instance of the error.
    var message: String
    
    /// Error details, type depends on `talerErrorCode`.
    var details: Data?
}

/// A request sent to the wallet backend.
struct WalletBackendRequest: Encodable {
    /// The operation name of the request.
    var operation: String
    
    /// The body of the request as JSON.
    var args: AnyEncodable
}

protocol WalletBackendFormattedRequest {
    associatedtype Args: Encodable
    associatedtype Response: Decodable
    
    func operation() -> String
    func args() -> Args
}

fileprivate struct WalletBackendInitRequest: WalletBackendFormattedRequest {
    var persistentStoragePath: String
    
    struct Args: Encodable {
        var persistentStoragePath: String
    }
    
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
    
    func operation() -> String {
        return "init"
    }
    
    func args() -> Args {
        return Args(persistentStoragePath: persistentStoragePath)
    }
}

/// An balance on a wallet.
struct Balance: Decodable {
    var available: Amount
    var pendingIncoming: Amount
    var pendingOutgoing: Amount
    var requiresUserInput: Bool
}

/// A request to get the balances held in the wallet.
struct WalletBackendGetBalancesRequest: WalletBackendFormattedRequest {
    struct Args: Encodable {
        
    }
    
    struct Response: Decodable {
        var balances: [Balance]
    }
    
    func operation() -> String {
        return "getBalances"
    }
    
    func args() -> Args {
        return Args()
    }
}

/// A billing or mailing location.
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

/// Information identifying a merchant.
struct Merchant: Codable {
    var name: String
    var address: Location?
    var jurisdiction: Location?
}

/// A tax made on a payment.
struct Tax: Codable {
    var name: String
    var tax: Amount
}

/// A product being purchased from a merchant.
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

/// Brief information about an order.
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

/// Different types of transactions.
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

/// An error associated with a transaction.
struct TransactionError: Codable {
    var ec: Int
    var hint: String?
    //var details: Any?
}

/// A wallet transaction.
struct Transaction: Codable {
    var transactionId: String
    var type: TransactionType
    var timestamp: Timestamp
    var pending: Bool
    var error: TransactionError?
    var amountRaw: Amount
    var amountEffective: Amount
}

/// A request to get the transactions in the wallet's history.
struct WalletBackendGetTransactionsRequest: WalletBackendFormattedRequest {
    var currency: String?
    var search: String?
    
    struct Args: Encodable {
        var currency: String?
        var search: String?
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "getTransactions"
    }
    
    func args() -> Args {
        return Args(currency: currency, search: search)
    }
}

/// A request to delete a wallet transaction by ID.
struct WalletBackendDeleteTransactionRequest: WalletBackendFormattedRequest {
    var transactionId: String
    
    struct Args: Encodable {
        var transactionId: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "deleteTransaction"
    }
    
    func args() -> Args {
        return Args(transactionId: transactionId)
    }
}

/// A request to process a refund.
struct WalletBackendApplyRefundRequest: WalletBackendFormattedRequest {
    var talerRefundUri: String
    
    struct Args: Encodable {
        var talerRefundUri: String
    }
    
    struct Response: Decodable {
        var contractTermsHash: String
        var amountEffectivePaid: Amount
        var amountRefundGranted: Amount
        var amountRefundGone: Amount
        var pendingAtExchange: Bool
        var info: OrderShortInfo
    }
    
    func operation() -> String {
        return "applyRefund"
    }
    
    func args() -> Args {
        return Args(talerRefundUri: talerRefundUri)
    }
}

/// A request to list exchanges.
struct WalletBackendListExchanges: WalletBackendFormattedRequest {
    struct Args: Encodable {
        
    }
    
    struct ExchangeListItem: Decodable {
        var exchangeBaseUrl: String
        var currency: String
        var paytoUris: [String]
    }
    
    struct Response: Decodable {
        var exchanges: [ExchangeListItem]
    }
    
    func operation() -> String {
        return "listExchanges"
    }
    
    func args() -> Args {
        return Args()
    }
}

/// A request to add an exchange.
struct WalletBackendAddRequest: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "addRequest"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl)
    }
}

/// A request to force update an exchange.
struct WalletBackendForceUpdateRequest: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "addRequest"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl)
    }
}

/// A request to query an exchange's terms of service.
struct WalletBackendGetExchangeTermsOfService: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    
    struct Response: Decodable {
        var tos: String
        var currentEtag: String
        var acceptedEtag: String
    }
    
    func operation() -> String {
        return "getExchangeTos"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl)
    }
}

/// A request to mark an exchange's terms of service as accepted.
struct WalletBackendSetExchangeTermsOfServiceAccepted: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    var acceptedEtag: String
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var acceptedEtag: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "setExchangeTosAccepted"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl, acceptedEtag: acceptedEtag)
    }
}

struct ExchangeListItem: Codable {
    var exchangeBaseUrl: String
    var currency: String
    var paytoUris: [String]
}

/// A request to get an exchange's withdrawal details.
struct WalletBackendGetWithdrawalDetailsForURIRequest: WalletBackendFormattedRequest {
    var talerWithdrawUri: String
    
    struct Args: Encodable {
        var talerWithdrawUri: String
    }
    
    struct Response: Decodable {
        var amount: Amount
        var defaultExchangeBaseUrl: String?
        var possibleExchanges: [ExchangeListItem]
    }
    
    func operation() -> String {
        return "getWithdrawalDetailsForUri"
    }
    
    func args() -> Args {
        return Args(talerWithdrawUri: talerWithdrawUri)
    }
}

/// A request to get an exchange's withdrawal details.
struct WalletBackendGetWithdrawalDetailsForAmountRequest: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    var amount: Amount
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
    
    struct Response: Decodable {
        var tosAccepted: Bool
        var amountRaw: Amount
        var amountEffective: Amount
    }
    
    func operation() -> String {
        return "getWithdrawalDetailsForAmount"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount)
    }
}

/// A request to accept a bank-integrated withdrawl.
struct WalletBackendAcceptBankIntegratedWithdrawalRequest: WalletBackendFormattedRequest {
    var talerWithdrawUri: String
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var talerWithdrawUri: String
        var exchangeBaseUrl: String
    }
    
    struct Response: Decodable {
        var bankConfirmationUrl: String?
    }
    
    func operation() -> String {
        return "acceptWithdrawal"
    }
    
    func args() -> Args {
        return Args(talerWithdrawUri: talerWithdrawUri, exchangeBaseUrl: exchangeBaseUrl)
    }
}

/// A request to accept a manual withdrawl.
struct WalletBackendAcceptManualWithdrawalRequest: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    var amount: Amount
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
    
    struct Response: Decodable {
        var exchangePaytoUris: [String]
    }
    
    func operation() -> String {
        return "acceptManualWithdrawal"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount)
    }
}

/// A request to deposit funds.
struct WalletBackendCreateDepositGroupRequest: WalletBackendFormattedRequest {
    var depositePayToUri: String
    var amount: Amount
    
    struct Args: Encodable {
        var depositPayToUri: String
        var amount: Amount
    }
    
    struct Response: Decodable {
        var depositGroupId: String
    }
    
    func operation() -> String {
        return "createDepositGroup"
    }
    
    func args() -> Args {
        return Args(depositPayToUri: depositePayToUri, amount: amount)
    }
}

/// A request to get information about a payment request.
struct WalletBackendPreparePayRequest: WalletBackendFormattedRequest {
    var talerPayUri: String
    
    struct Args: Encodable {
        var talerPayUri: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "preparePay"
    }
    
    func args() -> Args {
        return Args(talerPayUri: talerPayUri)
    }
}

/// A request to confirm a payment.
struct WalletBackendConfirmPayRequest: WalletBackendFormattedRequest {
    var proposalId: String
    
    struct Args: Encodable {
        var proposalId: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "abortFailedPayWithRefund"
    }
    
    func args() -> Args {
        return Args(proposalId: proposalId)
    }
}

/// A request to prepare a tip.
struct WalletBackendPrepareTipRequest: WalletBackendFormattedRequest {
    var talerTipUri: String
    
    struct Args: Encodable {
        var talerTipUri: String
    }
    
    struct Response: Decodable {
        var walletTipId: String
        var accepted: Bool
        var tipAmountRaw: Amount
        var tipAmountEffective: Amount
        var exchangeBaseUrl: String
        var expirationTimestamp: Timestamp
    }
    
    func operation() -> String {
        return "prepareTip"
    }
    
    func args() -> Args {
        return Args(talerTipUri: talerTipUri)
    }
}

/// A request to accept a tip.
struct WalletBackendAcceptTipRequest: WalletBackendFormattedRequest {
    var walletTipId: String
    
    struct Args: Encodable {
        var walletTipId: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "acceptTip"
    }
    
    func args() -> Args {
        return Args(walletTipId: walletTipId)
    }
}

/// A request to abort a failed payment.
struct WalletBackendAbortFailedPaymentRequest: WalletBackendFormattedRequest {
    var proposalId: String
    
    struct Args: Encodable {
        var proposalId: String
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "confirmPay"
    }
    
    func args() -> Args {
        return Args(proposalId: proposalId)
    }
}

/// A request to withdraw a balance from the TESTKUDOS environment.
struct WalletBackendWithdrawTestkudosRequest: WalletBackendFormattedRequest {
    struct Args: Encodable {
        
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "withdrawTestkudos"
    }
    
    func args() -> Args {
        return Args()
    }
}

/// A request to add a test balance to the wallet.
struct WalletBackendWithdrawTestBalance: WalletBackendFormattedRequest {
    var amount: Amount
    var bankBaseUrl: String
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var amount: Amount
        var bankBaseUrl: String
        var exchangeBaseUrl: String
    }
    typealias Response = String
    
    func operation() -> String {
        return "withdrawTestBalance"
    }
    
    func args() -> Args {
        return Args(amount: amount, bankBaseUrl: bankBaseUrl, exchangeBaseUrl: exchangeBaseUrl)
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

/// A request to run a basic integration test.
struct WalletBackendRunIntegrationTestRequest: WalletBackendFormattedRequest {
    var integrationTestArgs: IntegrationTestArgs
    
    typealias Args = IntegrationTestArgs
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "runIntegrationTest"
    }
    
    func args() -> Args {
        return integrationTestArgs
    }
}

struct TestPayArgs: Codable {
    var merchantBaseUrl: String
    var merchantApiKey: String
    var amount: String
    var summary: String
}

/// A request to make a test payment.
struct WalletBackendTestPayRequest: WalletBackendFormattedRequest {
    var testPayArgs: TestPayArgs
    
    typealias Args = TestPayArgs
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "testPay"
    }
    
    func args() -> Args {
        return testPayArgs
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

/// A request to dump all coins to JSON.
struct WalletBackendDumpCoinsRequest: WalletBackendFormattedRequest {
    struct Args: Encodable {
        
    }
    
    struct Response: Decodable {
        var coins: [Coin]
    }
    
    func operation() -> String {
        return "dumpCoins"
    }
    
    func args() -> Args {
        return Args()
    }
}

/// A request to suspend or unsuspend a coin.
struct WalletBackendSuspendCoinRequest: WalletBackendFormattedRequest {
    var coinPub: String
    var suspended: Bool
    
    struct Args: Encodable {
        var coinPub: String
        var suspended: Bool
    }
    
    struct Response: Decodable {
        
    }
    
    func operation() -> String {
        return "setCoinSuspended"
    }
    
    func args() -> Args {
        return Args(coinPub: coinPub, suspended: suspended)
    }
}

/// Errors for `WalletBackend`.
enum WalletBackendError: Error {
    /// An error that prevented the wallet from being initialized occurred.
    case initializationError
    case serializationError
    case deserializationError
}

/// Delegate for the wallet backend.
protocol WalletBackendDelegate {
    /// Called when the backend interface receives a message it does not know how to handle.
    func walletBackendReceivedUnknownMessage(_ walletBackend: WalletBackend, message: String)
}

/// An interface to the wallet backend.
class WalletBackend: IonoMessageHandler {
    private var iono: Iono
    private var requestsMade: UInt
    private var backendReady: Bool
    private var backendReadyCondition: NSCondition
    private var requests: [UInt : (AnyCodable?, WalletBackendResponseError?) -> Void] = [:]
    var delegate: WalletBackendDelegate?
    
    private struct FullRequest: Encodable {
        let operation: String
        let id: UInt
        let args: AnyEncodable
    }
    
    private struct FullResponse: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let result: AnyCodable
    }
    
    private struct FullError: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let error: WalletBackendResponseError
    }
    
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
            sendFormattedRequest(request: WalletBackendInitRequest(persistentStoragePath: storageDir.path), completionHandler: { (resp: WalletBackendInitRequest.Response?, err: WalletBackendResponseError?) in
                self.backendReady = true
                self.backendReadyCondition.broadcast()
            })
        }
        
        waitUntilReady()
    }
    
    deinit {
        iono.waitStopped()
    }
    
    func waitUntilReady() {
        backendReadyCondition.lock()
        while (!self.backendReady) {
            backendReadyCondition.wait()
        }
        backendReadyCondition.unlock()
    }
    
    func handleMessage(message: String) {
        do {
            guard let messageData = message.data(using: .utf8) else { throw WalletBackendError.deserializationError }
            let data = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [String : Any]
            if let responseData = data {
                let type = (responseData["type"] as? String) ?? ""
                if type == "response" {
                    guard let id = responseData["id"] as? UInt else { throw WalletBackendError.deserializationError }
                    guard let request = requests[id] else { throw WalletBackendError.deserializationError }
                    do {
                        let decoded = try JSONDecoder().decode(FullResponse.self, from: messageData)
                        request(decoded.result, nil)
                    } catch {
                        request(nil, WalletBackend.parseResponseError())
                    }
                    requests[id] = nil
                } else if type == "tunnelHttp" {
                    // TODO: Handle
                } else if type == "notification" {
                    // TODO: Handle
                } else if type == "error" {
                    guard let id = responseData["id"] as? UInt else { throw WalletBackendError.deserializationError }
                    guard let request = requests[id] else { throw WalletBackendError.deserializationError }
                    do {
                        let decoded = try JSONDecoder().decode(FullError.self, from: messageData)
                        request(nil, decoded.error)
                    } catch {
                        request(nil, WalletBackend.parseFailureError())
                    }
                    requests[id] = nil
                } else {
                    throw WalletBackendError.deserializationError
                }
            }
        } catch {
            self.delegate?.walletBackendReceivedUnknownMessage(self, message: message)
        }
    }
    
    func sendRequest(request: WalletBackendRequest, completionHandler: @escaping (AnyCodable?, WalletBackendResponseError?) -> Void) {
        /* Encode the request and send it to the backend. */
        do {
            let full = FullRequest(operation: request.operation, id: requestsMade, args: request.args)
            let encoded = try JSONEncoder().encode(full)
            guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
            requests[full.id] = completionHandler
            requestsMade += 1
            iono.sendMessage(message: jsonString)
        } catch {
            completionHandler(nil, WalletBackend.serializeRequestError());
        }
    }
    
    func sendFormattedRequest<T: WalletBackendFormattedRequest>(request: T, completionHandler: @escaping (T.Response?, WalletBackendResponseError?) -> Void) {
        let reqData = WalletBackendRequest(operation: request.operation(), args: AnyEncodable(request.args()))
        sendRequest(request: reqData) { (result: AnyCodable?, err: WalletBackendResponseError?) in
            if let res = result {
                do {
                    /* TODO: Don't use a hack (there is no reason to pass to JSON): */
                    let jsonStr = try JSONEncoder().encode(res)
                    let decoded = try JSONDecoder().decode(T.Response.self, from: jsonStr)
                    completionHandler(decoded, err)
                } catch {
                    completionHandler(nil, WalletBackend.parseResponseError())
                }
            } else {
                completionHandler(nil, err)
            }
        }
    }
    
    static func serializeRequestError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -1, talerErrorHint: "Could not serialize request.", message: "")
    }
    
    static func parseResponseError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -2, talerErrorHint: "Could not parse response.", message: "")
    }
    
    static func parseFailureError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -3, talerErrorHint: "Could not parse error detail.", message: "")
    }
}
