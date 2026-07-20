/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift

// MARK: -

enum BalanceFlag: String, Codable {
    case incomingAml = "incoming-aml"
    case incomingConfirmation = "incoming-confirmation"
    case incomingKyc = "incoming-kyc"
    case outgoingKyc = "outgoing-kyc"
}

/// A currency balance
struct Balance: Identifiable, Decodable, Hashable, Sendable {
    var id: String {
        if let url = scopeInfo.url {
            return url
        }
        return scopeInfo.currency   // only ISO 4217 currencies!
    }

    var scopeInfo: ScopeInfo
    var available: Amount
    var pendingIncoming: Amount
    var pendingOutgoing: Amount
    var flags: [BalanceFlag]
    var shoppingUrls: [String]?
    var disablePeerPayments: Bool?
    var disableDirectDeposits: Bool?                // TODO: en/disable actions based on this

    public static func == (lhs: Balance, rhs: Balance) -> Bool {
        lhs.scopeInfo == rhs.scopeInfo
        && lhs.available == rhs.available
        && lhs.pendingIncoming == rhs.pendingIncoming
        && lhs.pendingOutgoing == rhs.pendingOutgoing
        && lhs.flags == rhs.flags
        && lhs.disablePeerPayments == rhs.disablePeerPayments
        && lhs.disableDirectDeposits == rhs.disableDirectDeposits
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(scopeInfo)
        hasher.combine(available)
        hasher.combine(pendingIncoming)
        hasher.combine(pendingOutgoing)
        hasher.combine(flags)
        hasher.combine(disablePeerPayments)
        hasher.combine(disableDirectDeposits)
    }
}
extension Balance {
    static func firstwithDeposit(_ balances: [Balance]) -> Balance? {
        balances.first { balance in
            balance.disableDirectDeposits != true
        }
    }
    static func firstWithP2P(_ balances: [Balance]) -> Balance? {
        balances.first { balance in
            balance.disablePeerPayments != true
        }
    }
}
// MARK: -
struct BalancesResponse: Decodable, Hashable, Sendable {
    let haveProdBalance: Bool                           // if false, show DefaultExchange hint
    let balances: [Balance]
}

/// A request to get the balances held in the wallet.
fileprivate struct Balances: WalletBackendFormattedRequest {
    var operation: String { "getBalances" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed

    typealias Response = BalancesResponse
}
// MARK: -
struct TalerToken: Identifiable, Codable, Hashable, Sendable {
    // Hash of token family info.
    var tokenFamilyHash: String
    // Hash of token issue public key.
    var tokenIssuePubHash: String
    // URL of the merchant issuing the token.
    var merchantBaseUrl: String
    // Name of the merchant instance issuing the token.
    var merchantInfo: MerchantInfo?
    // Human-readable name for the token family.
    var name: String
    // Human-readable description for the token family.
    var description: String
    // Optional map from IETF BCP 47 language tags to localized descriptions.
    var descriptionI18n: I18nDict?
    // Start time of the token's validity period.
    var validityStart: Timestamp
    // End time of the token's validity period.
    var validityEnd: Timestamp
    // Number of tokens available to use.
    var tokensAvailable: Int?                   // Only for Discount

    var id: String {
        return tokenFamilyHash
    }
}
// MARK: -
struct DiscountsResponse: Decodable, Hashable, Sendable {
    let discounts: [TalerToken]
}

/// A request to get the discounts held in the wallet.
fileprivate struct ListDiscounts: WalletBackendFormattedRequest {
    var operation: String { "listDiscounts" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed

    typealias Response = DiscountsResponse
}
/// A request to delete a discount by ID.
struct DeleteDiscount: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "deleteDiscount" }
    func args() -> Args { Args(tokenFamilyHash: tokenFamilyHash) }

    var tokenFamilyHash: String
    struct Args: Encodable {
        var tokenFamilyHash: String
    }
}
// MARK: -
struct SubscriptionsResponse: Decodable, Hashable, Sendable {
    let subscriptions: [TalerToken]
}

/// A request to get the subscriptions held in the wallet.
fileprivate struct ListSubscriptions: WalletBackendFormattedRequest {
    var operation: String { "listSubscriptions" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed

    typealias Response = SubscriptionsResponse
}
/// A request to delete a subscription by ID.
struct DeleteSubscription: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "deleteSubscription" }
    func args() -> Args { Args(tokenFamilyHash: tokenFamilyHash) }

    var tokenFamilyHash: String
    struct Args: Encodable {
        var tokenFamilyHash: String
    }
}
// MARK: -
extension WalletModel {
    /// fetch Balances from Wallet-Core. No networking involved
    nonisolated func getBalances(_ stack: CallStack, viewHandles: Bool = false) async throws -> BalancesResponse {
        let request = Balances()
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
    /// fetch Discounts from Wallet-Core. No networking involved
    nonisolated func listDiscounts(_ stack: CallStack, viewHandles: Bool = false) async throws -> DiscountsResponse {
        let request = ListDiscounts()
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
    /// delete a discount. No networking involved
    nonisolated func deleteDiscount(_ tokenID: String, viewHandles: Bool = false) async throws {
        let request = DeleteDiscount(tokenFamilyHash: tokenID)
        logger.notice("deleteDiscount: \(tokenID, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
    /// fetch Subscriptions from Wallet-Core. No networking involved
    nonisolated func listSubscriptions(_ stack: CallStack, viewHandles: Bool = false) async throws -> SubscriptionsResponse {
        let request = ListSubscriptions()
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
    /// delete a subscription. No networking involved
    nonisolated func deleteSubscription(_ tokenID: String, viewHandles: Bool = false) async throws {
        let request = DeleteSubscription(tokenFamilyHash: tokenID)
        logger.notice("deleteSubscription: \(tokenID, privacy: .private(mask: .hash))")
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
