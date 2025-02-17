/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -

enum BalanceFlag: String, Codable {
    case incomingAml = "incoming-aml"
    case incomingConfirmation = "incoming-confirmation"
    case incomingKyc = "incoming-kyc"
    case outgoingKyc = "outgoing-kyc"
}

/// A currency balance
struct Balance: Decodable, Hashable, Sendable {
    var scopeInfo: ScopeInfo
    var available: Amount
    var pendingIncoming: Amount
    var pendingOutgoing: Amount
    var flags: [BalanceFlag]

    public static func == (lhs: Balance, rhs: Balance) -> Bool {
        lhs.scopeInfo == rhs.scopeInfo
        && lhs.available == rhs.available
        && lhs.pendingIncoming == rhs.pendingIncoming
        && lhs.pendingOutgoing == rhs.pendingOutgoing
        && lhs.flags == rhs.flags
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(scopeInfo)
        hasher.combine(available)
        hasher.combine(pendingIncoming)
        hasher.combine(pendingOutgoing)
        hasher.combine(flags)
    }
}
extension Balance {
    static func nonZeroBalances(_ balances: [Balance]) -> [Balance] {
        balances.filter { balance in
            !balance.available.isZero
        }
    }
    static func firstNonZero(_ balances: [Balance]) -> Balance? {
        for balance in balances {
            if !balance.available.isZero {
                return balance
            }
        }
        return nil
    }
}
// MARK: -
/// A request to get the balances held in the wallet.
fileprivate struct Balances: WalletBackendFormattedRequest {
    func operation() -> String { "getBalances" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed

    struct Response: Decodable, Sendable {              // list of balances
        var balances: [Balance]
    }
}
// MARK: -
extension WalletModel {
    /// fetch Balances from Wallet-Core. No networking involved
    nonisolated func getBalances(_ stack: CallStack, viewHandles: Bool = false) async throws -> [Balance] {
        let request = Balances()
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.balances
    }
}
