/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: - IBAN
/// The result from PrepareDeposit
struct ValidateIbanResult: Codable {
    let valid: Bool
}
/// A request to get an validate an IBAN.
fileprivate struct ValidateIban: WalletBackendFormattedRequest {
    typealias Response = ValidateIbanResult
    func operation() -> String { "validateIban" }
    func args() -> Args { Args(iban: iban) }

    var iban: String
    struct Args: Encodable {
        var iban: String
    }
}

// MARK: - Deposit
struct DepositFees: Codable {
    let coin: Amount
    let wire: Amount
    let refresh: Amount
}

/// The result from PrepareDeposit
struct PrepareDepositResult: Codable {
    let totalDepositCost: Amount
    let effectiveDepositAmount: Amount
    let fees: DepositFees
}
/// A request to get an exchange's deposit contract terms.
fileprivate struct PrepareDeposit: WalletBackendFormattedRequest {
    typealias Response = PrepareDepositResult
    func operation() -> String { "prepareDeposit" }
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri, amount: amount) }

    var depositPaytoUri: String
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var amount: Amount
    }
}
// MARK: -
/// The result from CreateDepositGroup
struct DepositGroupResult: Decodable {
    var depositGroupId: String
    var transactionId: String
}
/// A request to deposit some coins.
fileprivate struct CreateDepositGroup: WalletBackendFormattedRequest {
    typealias Response = DepositGroupResult
    func operation() -> String { "createDepositGroup" }
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri, amount: amount) }

    var depositPaytoUri: String
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var amount: Amount
    }
}
// MARK: -
extension WalletModel {
    /// validate IBAN
    @MainActor
    func validateIbanM(_ iban: String)       // M for MainActor
    async throws -> Bool {
        let request = ValidateIban(iban: iban)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response.valid
    }

    /// deposit coins. Networking involved
    @MainActor
    func prepareDepositM(_ depositPaytoUri: String, amount: Amount)       // M for MainActor
      async throws -> PrepareDepositResult {
          let request = PrepareDeposit(depositPaytoUri: depositPaytoUri, amount: amount)
          let response = try await sendRequest(request, ASYNCDELAY)
          return response
    }

    @MainActor
    func createDepositGroupM(_ depositPaytoUri: String, amount: Amount)  // M for MainActor
      async throws -> DepositGroupResult {
          let request = CreateDepositGroup(depositPaytoUri: depositPaytoUri, amount: amount)
          let response = try await sendRequest(request, ASYNCDELAY)
          return response
    }
}
