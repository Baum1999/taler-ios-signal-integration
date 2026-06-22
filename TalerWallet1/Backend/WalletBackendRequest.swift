/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Jonathan Buchanan
 * @author Marc Stibane
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
/// The scope of a currency: either global or a dedicated exchange
struct ScopeInfo: Codable, Hashable {
    enum ScopeInfoType: String, Codable {
        case global
        case exchange
        case auditor
        case madeUp     // => type unknown, currency name taken from amount
    }
    var type: ScopeInfoType
    var currency: String        // 3-char ISO 4217 code for global currency. Regional MUST be >= 4 letters
    var noFees: Bool?           // only for "global". Regional have this field per Exchange
    var url: String?            // only for "exchange" and "auditor"

    public static func zero() -> ScopeInfo {
        ScopeInfo(type: .madeUp, currency: UNKNOWN)
    }
    public static func zero(_ currency: String) -> ScopeInfo {
        ScopeInfo(type: .madeUp, currency: currency)
    }
    public static func < (lhs: ScopeInfo, rhs: ScopeInfo) -> Bool {
        if lhs.type == .global {
            if rhs.type == .global {        // both global ==> alphabetic currency
                return lhs.currency < rhs.currency
            }
            return true                     // global comes first
        }
        if rhs.type == .global {
            return false                    // global comes first
        }
        if lhs.currency == rhs.currency {
            if let lhsBaseURL = lhs.url {
                if let rhsBaseURL = rhs.url {
                    return lhsBaseURL < rhsBaseURL
                }
                return true
            }
            if rhs.url != nil {
                return false
            }
            // fall thru
        }
        return lhs.currency < rhs.currency
    }
    public static func == (lhs: ScopeInfo, rhs: ScopeInfo) -> Bool {
        if let lhsBaseURL = lhs.url {
            if let rhsBaseURL = rhs.url {
                if lhsBaseURL != rhsBaseURL { return false }    // different exchanges
                                                                // else fall thru and check type & currency
            } else { return false }                             // left but not right
        } else if rhs.url != nil {
            return false                                        // right but not left
        }
        return lhs.type == rhs.type &&
        lhs.currency == rhs.currency
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        if let url {
            hasher.combine(url)
        }
        hasher.combine(currency)
    }
}
// MARK: -
/// A billing or mailing location.
struct Location: Codable, Equatable, Hashable {
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
struct MerchantInfo: Identifiable, Codable, Hashable, Sendable {
    var name: String
    var email: String?
    var website: String?
    var logo: String?       // ImageDataUrl
    var address: Location?
    var jurisdiction: Location?

    var id: String {
        return name + (email ?? EMPTYSTRING)
    }
}

/// A tax made on a payment.
struct Tax: Codable {
    var name: String
    var tax: Amount
}

/// A product being purchased from a merchant.
/// https://docs.taler.net/core/api-merchant.html#the-contract-terms
struct Product: Codable, Identifiable {
    var product_id: String?
    var description: String
//    var description_i18n:   ?
    var quantity: Int?
    var unit: String?
    var price: Amount?
    var image: String? // product image 128x128 encoded
    var taxes: [Tax]?
    var delivery_date: Timestamp?

    var id: String { product_id ?? "unknown" }
}

/// Brief information about an order.
struct OrderShortInfo: Codable {
    var orderId: String
    var merchant: MerchantInfo
    var summary: String
    var summary_i18n: I18nDict?
    var products: [Product]?
    var fulfillmentUrl: String?
    var fulfillmentMessage: String?
    var fulfillmentMessage_i18n: I18nDict?
    var contractTermsHash: String?
}
// MARK: -
/// A request to process a refund.
struct WalletBackendApplyRefundRequest: WalletBackendFormattedRequest {
    func operation() -> String { "applyRefund" }
    func args() -> Args { Args(talerRefundUri: talerRefundUri) }

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
}


/// A request to force update an exchange.
struct WalletBackendForceUpdateRequest: WalletBackendFormattedRequest {
    func operation() -> String { "addRequest" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }

    struct Response: Decodable {}
}

/// A request to deposit funds.
struct WalletBackendCreateDepositGroupRequest: WalletBackendFormattedRequest {
    func operation() -> String { "createDepositGroup" }
    func args() -> Args { Args(depositPayToUri: depositePayToUri, amount: amount) }

    var depositePayToUri: String
    var amount: Amount
    
    struct Args: Encodable {
        var depositPayToUri: String
        var amount: Amount
    }
    
    struct Response: Decodable {
        var depositGroupId: String
    }
}

/// A request to get information about a payment request.
struct WalletBackendPreparePayRequest: WalletBackendFormattedRequest {
    func operation() -> String { "preparePay" }
    func args() -> Args { Args(talerPayUri: talerPayUri) }
    var talerPayUri: String

    struct Args: Encodable {
        var talerPayUri: String
    }

    struct Response: Decodable {}
}

// MARK: -
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
    func operation() -> String { "runIntegrationTest" }
    func args() -> Args { integrationTestArgs }
    var integrationTestArgs: IntegrationTestArgs
    
    typealias Args = IntegrationTestArgs
    
    struct Response: Decodable {}
}

struct TestPayArgs: Codable {
    var merchantBaseUrl: String
    var merchantApiKey: String
    var amount: String
    var summary: String
}

/// A request to make a test payment.
struct WalletBackendTestPayRequest: WalletBackendFormattedRequest {
    func operation() -> String { "testPay" }
    func args() -> Args { testPayArgs }

    var testPayArgs: TestPayArgs
    typealias Args = TestPayArgs
    
    struct Response: Decodable {}
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
    func operation() -> String { "dumpCoins" }
    func args() -> Args { Args() }
    struct Args: Encodable { }

    struct Response: Decodable {
        var coins: [Coin]
    }
    
}

/// A request to suspend or unsuspend a coin.
struct WalletBackendSuspendCoinRequest: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { "setCoinSuspended" }
    func args() -> Args { Args(coinPub: coinPub, suspended: suspended) }

    var coinPub: String
    var suspended: Bool
    
    struct Args: Encodable {
        var coinPub: String
        var suspended: Bool
    }
}


