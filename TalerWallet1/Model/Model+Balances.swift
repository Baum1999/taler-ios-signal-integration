/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
    @MainActor func balancesM(_ stack: CallStack)
      async -> [Balance] {          // M for MainActor
        await semaphore.wait()
        defer { semaphore.signal() }
        if cachedBalances == nil {
            do {
                let request = Balances()
                let response = try await sendRequest(request, ASYNCDELAY)
                cachedBalances = response.balances
            } catch {
                logger.error("balancesM failed: \(error)")
                // TODO: show error
            }
        } else {
            logger.trace("returning cached Balances")
        }
        return cachedBalances ?? []
    }
}
