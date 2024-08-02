/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: - IBAN
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
struct CheckDepositResult: Codable {
    let totalDepositCost: Amount
    let effectiveDepositAmount: Amount
    let fees: DepositFees
}
/// A request to get an exchange's deposit contract terms.
fileprivate struct CheckDeposit: WalletBackendFormattedRequest {
    typealias Response = CheckDepositResult
    func operation() -> String { "checkDeposit" }
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri, amount: amount,
                          clientCancellationId: "cancel") }

    var depositPaytoUri: String
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var amount: Amount
        var clientCancellationId: String?
    }
}
// MARK: -
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
    /// validate IBAN. No Networking
    @MainActor    // M for MainActor
    func validateIbanM(_ iban: String, viewHandles: Bool = false)
    async throws -> Bool {
        let request = ValidateIban(iban: iban)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.valid
    }

    /// check fees for deposit. No Networking
    @MainActor    // M for MainActor
    func checkDepositM(_ depositPaytoUri: String, amount: Amount, viewHandles: Bool = false)
      async throws -> CheckDepositResult {
          let request = CheckDeposit(depositPaytoUri: depositPaytoUri, amount: amount)
          let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
          return response
    }

    /// deposit coins. Networking involved
    @MainActor          // M for MainActor
    func createDepositGroupM(_ depositPaytoUri: String, amount: Amount, viewHandles: Bool = false)
      async throws -> DepositGroupResult {
          let request = CreateDepositGroup(depositPaytoUri: depositPaytoUri, amount: amount)
          let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
          return response
    }
}
