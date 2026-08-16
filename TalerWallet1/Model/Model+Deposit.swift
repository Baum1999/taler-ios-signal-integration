/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import AnyCodable
//import SymLog

struct AccountChange: Codable {             // Notification
    enum TransitionType: String, Codable {
        case change = "bank-account-change"
    }
    var type: TransitionType
    var bankAccountId: String
}

// MARK: - IBAN
struct ValidateIbanResult: Codable {
    let valid: Bool
}
/// A request to validate an IBAN.
fileprivate struct ValidateIban: WalletBackendFormattedRequest {
    typealias Response = ValidateIbanResult
    var operation: String { "validateIban" }
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
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response.valid
    }
}
// MARK: - Deposit
enum PaytoType: String, Codable {
    case unknown
    case iban       // or BBAN for HUF (and CHF when taler://dev-experiment/fake-chf-bban was called)
    case bitcoin
    case cyclos
    case xTalerBank = "x-taler-bank"
}

struct IbanAccountFieldToPaytoResponse: Codable {
    let ok: Bool
    let type: String?       // either "iban" or "bban", only if ok==true
    let paytoUri: String?   // only if ok==true
}

/// A request to convert an IBAN/BBAN to PayTo.
fileprivate struct IbanAccountFieldToPayto: WalletBackendFormattedRequest {
    typealias Response = IbanAccountFieldToPaytoResponse
    var operation: String { "convertIbanAccountFieldToPayto" }
    func args() -> Args { Args(value: value, currency: currency) }

    var value: String
    var currency: String
    struct Args: Encodable {
        var value: String
        var currency: String
    }
}

struct IbanPaytoToAccountFieldResponse: Codable {
    let type: String
    let value: String
}

/// A request to convert PayTo to IBAN/BBAN.
fileprivate struct IbanPaytoToAccountField: WalletBackendFormattedRequest {
    typealias Response = IbanPaytoToAccountFieldResponse
    var operation: String { "convertIbanPaytoToAccountField" }
    func args() -> Args { Args(paytoUri: paytoUri) }

    var paytoUri: String
    struct Args: Encodable {
        var paytoUri: String
    }
}

extension WalletModel {
    /// convert an IBAN/BBAN to PayTo
    nonisolated func convertIbanAccountFieldToPayto(_ value: String, currency: String, viewHandles: Bool = false)
      async throws -> IbanAccountFieldToPaytoResponse {
        let request = IbanAccountFieldToPayto(value: value, currency: currency)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
    nonisolated func convertIbanPaytoToAccountField(_ paytoUri: String, viewHandles: Bool = false)
      async throws -> IbanPaytoToAccountFieldResponse {
        let request = IbanPaytoToAccountField(paytoUri: paytoUri)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
// MARK: - Deposit
struct WireTypeDetails: Codable {
    let paymentTargetType: PaytoType
    let preferredEntryType: String?         // iban / bban  TODO: use this
    let talerBankHostnames: [String]?
}

struct DepositWireTypesResponse: Codable {
    /// can be used to pre-filter payment target types to offer the user as an input option
//    let wireTypes: [PaytoType]
    let wireTypeDetails: [WireTypeDetails]
}

/// A request to get wire types that can be used for a deposit operation.
fileprivate struct DepositWireTypes: WalletBackendFormattedRequest {
    typealias Response = DepositWireTypesResponse
    var operation: String { "getDepositWireTypes" }
    func args() -> Args { Args(currency: currency, scopeInfo: scopeInfo) }

    var currency: String?
    var scopeInfo: ScopeInfo?
    struct Args: Encodable {
        // one of these must be set - don't set both to nil
        var currency: String?
        var scopeInfo: ScopeInfo?
    }
}
extension WalletModel {
    /// Get wire types that can be used for a deposit operation
    nonisolated func depositWireTypes(_ currency: String?, scopeInfo: ScopeInfo? = nil, viewHandles: Bool = false)
      async throws -> [WireTypeDetails] {
        let request = DepositWireTypes(currency: currency, scopeInfo: scopeInfo)
        let response = try await sendRequest(request, viewHandles: viewHandles)
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
    var operation: String { "getMaxDepositAmount" }
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
        let response = try await sendRequest(request, viewHandles: viewHandles)
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
    let kycSoftLimit: Amount?
    let kycHardLimit: Amount?
    let kycExchanges: [String]?                 // Base URL of exchanges that would likely require soft KYC
}
/// A request to get an exchange's deposit contract terms.
fileprivate struct CheckDeposit: WalletBackendFormattedRequest {
    typealias Response = CheckDepositResponse
    var operation: String { "checkDeposit" }
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
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
// MARK: -
struct DepositGroupResult: Decodable {
    var transactionId: String
    var txState: TransactionState?
}
/// A request to deposit some coins.
fileprivate struct CreateDepositGroup: WalletBackendFormattedRequest {
    typealias Response = DepositGroupResult
    var operation: String { "createDepositGroup" }
    func args() -> Args { Args(depositPaytoUri: depositPaytoUri,
                                 restrictScope: scope,
                                        amount: amount,
                                 progressToken: depositPaytoUri) }
    var depositPaytoUri: String
    var scope: ScopeInfo
    var amount: Amount
    struct Args: Encodable {
        var depositPaytoUri: String
        var restrictScope: ScopeInfo
        var amount: Amount
        var progressToken: String
    }
}
extension WalletModel {
    /// deposit coins. Networking involved
    nonisolated func createDepositGroup(_ depositPaytoUri: String, scope: ScopeInfo, amount: Amount, viewHandles: Bool = false)
      async throws -> DepositGroupResult {
        let request = CreateDepositGroup(depositPaytoUri: depositPaytoUri, scope: scope, amount: amount)
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = depositPaytoUri
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}
// MARK: -
struct BankAccountsInfo: Decodable, Hashable {
    var bankAccountId: String
    var paytoUri: String
    var kycCompleted: Bool
    var currencies: [String]?       // Currencies supported by the bank, if known
    var label: String?
    var payToWorkAround: String {
        let payto = PayTo(paytoUri)
        
        if let cyclos = payto.cyclos {
            if cyclos.count > 1 {
                // TODO: wallet-core should ensure that receivers are valid and don't have whitespace
                // https://bugs.gnunet.org/view.php?id=11726
                let receiver = payto.receiver?.replacingOccurrences(of: SPACE, with: "+") ?? DEMO
                return String("payto://cyclos/\(cyclos)?receiver-name=\(receiver)")
            }
        }
        return paytoUri
    }
}
struct BankAccounts: Decodable, Hashable {
    var accounts: [BankAccountsInfo]
}
/// A request to list known bank accounts.
fileprivate struct ListBankAccounts: WalletBackendFormattedRequest {
    typealias Response = BankAccounts
    var operation: String { "listBankAccounts" }
    func args() -> Args { Args(currency: currency) }
    var currency: String?
    struct Args: Encodable {
        var currency: String?
    }
}
extension WalletModel {
    /// ask for known accounts. No networking
    nonisolated func listBankAccounts(_ currency: String? = nil, viewHandles: Bool = false)
      async throws -> [BankAccountsInfo] {
        let request = ListBankAccounts(currency: currency)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response.accounts
    }
}

/// A request to get one bank account.
fileprivate struct GetBankAccountById: WalletBackendFormattedRequest {
    typealias Response = BankAccountsInfo
    var operation: String { "getBankAccountById" }
    func args() -> Args { Args(bankAccountId: bankAccountId) }
    var bankAccountId: String
    struct Args: Encodable {
        var bankAccountId: String
    }
}
extension WalletModel {
    /// ask for a specific account. No networking
    nonisolated func getBankAccountById(_ bankAccountId: String, viewHandles: Bool = false)
      async throws -> BankAccountsInfo {
        let request = GetBankAccountById(bankAccountId: bankAccountId)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }
}

struct AddBankAccountResponse: Decodable, Hashable {
    var bankAccountId: String                       // Identifier of the added bank account
}
/// A request to add a known bank account.
fileprivate struct AddBankAccount: WalletBackendFormattedRequest {
    typealias Response = AddBankAccountResponse
    var operation: String { "addBankAccount" }
    func args() -> Args { Args(paytoUri: uri,
                                  label: label,
                   replaceBankAccountId: replace) }
    var uri: String
    var label: String
    var replace: String?
    struct Args: Encodable {
        var paytoUri: String                        // bank account that should be added
        var label: String                           // Human-readable label
        var replaceBankAccountId: String?                // account that this new account should replace
    }
}
extension WalletModel {
    /// add (or update) a known account. No networking
    nonisolated func addBankAccount(_ uri: String,
                                    label: String,
                                  replace: String? = nil,
                              viewHandles: Bool = false)
      async throws -> String {
        let request = AddBankAccount(uri: uri, label: label, replace: replace)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response.bankAccountId
    }
}

/// A request to forget a known bank account.
fileprivate struct ForgetBankAccount: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    var operation: String { "forgetBankAccount" }
    func args() -> Args { Args(bankAccountId: accountId) }
    var accountId: String
    struct Args: Encodable {
        var bankAccountId: String                        // bank account that should be forgotten
    }
}
extension WalletModel {
    /// add a known account. No networking
    nonisolated func forgetBankAccount(_ accountId: String, viewHandles: Bool = false)
      async throws {
        let request = ForgetBankAccount(accountId: accountId)
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
