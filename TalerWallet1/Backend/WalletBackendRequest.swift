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
import AnyCodable
import taler_swift

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
// MARK: -


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


/// A request to delete a wallet transaction by ID.
struct WalletBackendDeleteTransactionRequest: WalletBackendFormattedRequest {
    var transactionId: String
    
    struct Args: Encodable {
        var transactionId: String
    }
    
    struct Response: Decodable {}
    
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


/// A request to force update an exchange.
struct WalletBackendForceUpdateRequest: WalletBackendFormattedRequest {
    var exchangeBaseUrl: String
    
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    
    struct Response: Decodable {}
    
    func operation() -> String {
        return "addRequest"
    }
    
    func args() -> Args {
        return Args(exchangeBaseUrl: exchangeBaseUrl)
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
    
    struct Response: Decodable {}
    
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
    
    struct Response: Decodable {}
    
    func operation() -> String {
        return "confirmPay"
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
    
    struct Response: Decodable {}
    
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
    
    struct Response: Decodable {}
    
    func operation() -> String {
        return "abortFailedPayWithRefund"
    }
    
    func args() -> Args {
        return Args(proposalId: proposalId)
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
    
    struct Response: Decodable {}
    
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
    
    struct Response: Decodable {}
    
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
    
    struct Response: Decodable {}
    
    func operation() -> String {
        return "setCoinSuspended"
    }
    
    func args() -> Args {
        return Args(coinPub: coinPub, suspended: suspended)
    }
}


