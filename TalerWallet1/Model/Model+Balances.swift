/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
        return scopeInfo.currency
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
    func operation() -> String { "getBalances" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed

    typealias Response = BalancesResponse
}
// MARK: -
extension WalletModel {
    /// fetch Balances from Wallet-Core. No networking involved
    nonisolated func getBalances(_ stack: CallStack, viewHandles: Bool = false) async throws -> BalancesResponse {
        let request = Balances()
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
