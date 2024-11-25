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
/// A request to validate an IBAN.
fileprivate struct ValidateIban: WalletBackendFormattedRequest {
    typealias Response = ValidateIbanResult
    func operation() -> String { "validateIban" }
    func args() -> Args { Args(iban: iban) }

    var iban: String
    struct Args: Encodable {
        var iban: String
    }
}
extension WalletModel {
    /// validate IBAN. No Networking
    nonisolated func validateIban(_ iban: String, viewHandles: Bool = false)
      async throws -> Bool {
        let request = ValidateIban(iban: iban)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.valid
    }
}
// MARK: - Deposit
enum PaytoType: String, Codable {
    case unknown
    case iban
    case bitcoin
    case xTalerBank = "x-taler-bank"
}

struct WireTypeDetails: Codable {
    let paymentTargetType: PaytoType
    let talerBankHostnames: [String]
}

struct DepositWireTypesForCurrencyResponse: Codable {
    /// can be used to pre-filter payment target types to offer the user as an input option
//    let wireTypes: [PaytoType]
    let wireTypeDetails: [WireTypeDetails]
}

/// A request to get wire types that can be used for a deposit operation.
fileprivate struct DepositWireTypesForCurrency: WalletBackendFormattedRequest {
    typealias Response = DepositWireTypesForCurrencyResponse
    func operation() -> String { "getDepositWireTypesForCurrency" }
    func args() -> Args { Args(currency: currency, scopeInfo: scopeInfo) }

    var currency: String
    var scopeInfo: ScopeInfo?
    struct Args: Encodable {
        var currency: String
        var scopeInfo: ScopeInfo?
    }
}
extension WalletModel {
    /// Get wire types that can be used for a deposit operation
    nonisolated func depositWireTypesForCurrency(_ currency: String, scopeInfo: ScopeInfo? = nil, viewHandles: Bool = false)
      async throws -> [WireTypeDetails] {
        let request = DepositWireTypesForCurrency(currency: currency, scopeInfo: scopeInfo)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.wireTypeDetails
    }
}
// MARK: - max Deposit amount
/// Check if initiating a deposit is possible, check fees
fileprivate struct AmountResponse: Codable {
    let effectiveAmount: Amount?
    let rawAmount: Amount
}
fileprivate struct GetMaxDepositAmount: WalletBackendFormattedRequest {
    typealias Response = AmountResponse
    func operation() -> String { "getMaxDepositAmount" }
    func args() -> Args { Args(currency: scope.currency, restrictScope: scope) }

    var scope: ScopeInfo
    struct Args: Encodable {
        var currency: String
        var restrictScope: ScopeInfo
//        var depositPaytoUri: String
    }
}
extension WalletModel {
    nonisolated func getMaxDepositAmount(_ scope: ScopeInfo, viewHandles: Bool = false)
      async throws -> Amount {
        let request = GetMaxDepositAmount(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.rawAmount
    }
} // getMaxDepositAmount
// MARK: - Deposit
struct DepositFees: Codable {
    let coin: Amount
    let wire: Amount
    let refresh: Amount
}
struct CheckDepositResponse: Codable {
    let totalDepositCost: Amount
    let effectiveDepositAmount: Amount
    let fees: DepositFees
}
/// A request to get an exchange's deposit contract terms.
fileprivate struct CheckDeposit: WalletBackendFormattedRequest {
    typealias Response = CheckDepositResponse
    func operation() -> String { "checkDeposit" }
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri,
                                        amount: amount,
                          clientCancellationId: "cancel") }
    var depositPaytoUri: String
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var amount: Amount
        var clientCancellationId: String?
    }
}
extension WalletModel {
    /// check fees for deposit. No Networking
    nonisolated func checkDeposit4711(_ depositPaytoUri: String, amount: Amount, viewHandles: Bool = false)
      async throws -> CheckDepositResponse {
        let request = CheckDeposit(depositPaytoUri: depositPaytoUri, amount: amount)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
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
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri,
                                        amount: amount) }
    var depositPaytoUri: String
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var amount: Amount
    }
}
extension WalletModel {
    /// deposit coins. Networking involved
    nonisolated func createDepositGroup(_ depositPaytoUri: String, amount: Amount, viewHandles: Bool = false)
      async throws -> DepositGroupResult {
        let request = CreateDepositGroup(depositPaytoUri: depositPaytoUri, amount: amount)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response
    }
}
