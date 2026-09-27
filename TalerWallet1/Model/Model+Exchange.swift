/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Model+Exchange
 *
 * @author Marc Stibane
 */
import Foundation
import taler_swift
import SymLog

struct OperationErrorInfo: Codable, Hashable {
    var error: TalerErrorDetail
}

enum ExchangeType: String, Codable {
    case demo
    case prod
}

enum ExchangeEntryStatus: String, Codable {
    case preset
    case ephemeral
    case used
}

enum ExchangeUpdateStatus: String, Codable {
    case initial
    case initialUpdate = "initial-update"
    case suspended
//    case failed
    case outdatedUpdate = "outdated-update"
    case ready
    case readyUpdate = "ready-update"
    case unavailable            // even if wallet-core doesn't support this, we need it for L10n
    case unavailableUpdate = "unavailable-update"

    var localized: String {
        switch self {
            case .initial:           String(localized: "Exchange_status_initial", defaultValue: "Initial")
            case .initialUpdate:     String(localized: "Exchange_status_initial_update", defaultValue: "Initial (… updating …)")
            case .suspended:         String(localized: "Exchange_status_suspended", defaultValue: "Suspended")
//            case .failed:            String(localized: "Exchange_status_failed", defaultValue: "Failed")
            case .outdatedUpdate:    String(localized: "Exchange_status_outdated_update", defaultValue: "Outdated (… updating …)")
            case .ready:             String(localized: "Exchange_status_ready", defaultValue: "Ready")
            case .readyUpdate:       String(localized: "Exchange_status_ready_update", defaultValue: "Ready (… updating …)")
            case .unavailable:       String(localized: "Exchange_status_unavailable", defaultValue: "Unavailable")
            case .unavailableUpdate: String(localized: "Exchange_status_unavailable_update", defaultValue: "Unavailable (… updating …)")
        }
    }
}

struct ExchangeState: Codable, Hashable {
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var tosStatus: ExchangeTosStatus
}

/// Set on an Exchange when it changed its master key and the user has not
/// confirmed the change yet. Withdrawals are refused while this is present
/// (wallet-core throws WALLET_EXCHANGE_KEYS_NOT_ACCEPTED), until the app calls
/// confirmExchangeKeyChange().
struct ExchangeKeyChangeInfo: Codable, Hashable {
    var currentMasterPub: String
    var currentCurrency: String
    var supersededMasterPub: String
    var supersededCurrency: String
    var sharesDenominations: Bool
    var firstSeen: Timestamp?
}

struct ExchangeTransition: Codable {             // Notification
    var type: String        // exchange-state-transition
    var exchangeBaseUrl: String
    var oldExchangeState: ExchangeState
    var newExchangeState: ExchangeState
}

enum BankDialect: Codable, Hashable {
    case gls
    case unknown(value: String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try? container.decode(String.self)
        switch string {
            case "gls": self = .gls
            default:
                self = .unknown(value: string ?? "unknown")
        }
    }
}

enum ExchangeSource: Codable, Hashable {
    case builtin
    case user
    case discovered
    case unknown(value: String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try? container.decode(String.self)
        switch string {
            case "builtin": self = .builtin
            case "user": self = .user
            case "discovered": self = .discovered
            default:
                self = .unknown(value: string ?? "unknown")
        }
    }
}
// MARK: -
/// The result from wallet-core's ListExchanges
struct Exchange: Codable, Hashable, Identifiable {
    static func < (lhs: Exchange, rhs: Exchange) -> Bool {
        let leftScope = lhs.scopeInfo
        let rightScope = rhs.scopeInfo
        return leftScope < rightScope
    }
    static func == (lhs: Exchange, rhs: Exchange) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl
        &&     lhs.tosStatus == rhs.tosStatus
//        &&     lhs.exchangeStatus == rhs.exchangeStatus                         // deprecated
        &&     lhs.exchangeEntryStatus == rhs.exchangeEntryStatus
        &&     lhs.exchangeUpdateStatus == rhs.exchangeUpdateStatus
    }

    var exchangeBaseUrl: String
    var source: ExchangeSource?
    var masterPub: String?
    var legacyMasterPubs: [String]?
    var scopeInfo: ScopeInfo
    var paytoUris: [String]
    var tosStatus: ExchangeTosStatus
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var peerPaymentsDisabled: Bool?
    var directDepositsDisabled: Bool?
    var noFees: Bool?
    var ageRestrictionOptions: [Int]
    var bankComplianceLanguage: BankDialect?
    var lastUpdateTimestamp: Timestamp?
    var lastWithdrawal: Timestamp?
    var lastUpdateErrorInfo: OperationErrorInfo?
    var unconfirmedKeyChange: ExchangeKeyChangeInfo?    // if set, withdrawals are refused until confirmed
    var currencySpec: CurrencySpecification?            // .name = "Swiss Francs"... alt_unit_names":{"0":"Fr.","-2":"Rp."}

//    walletKycStatus?: ExchangeWalletKycStatus;
//    walletKycReservePub?: string;
//    walletKycAccessToken?: string;
//    walletKycUrl?: string;

    /** Threshold that we've requested to satisfy. */
//    walletKycRequestedThreshold?: string;

    var id: String { exchangeBaseUrl + tosStatus.rawValue }
    var name: String? {
        if let url = URL(string: exchangeBaseUrl) {
            if let host = url.host {
                return host
            }
        }
        return nil
    }
}
// MARK: -
struct DefaultExchange: Codable, Hashable {
    var talerUri: String                            // taler://withdraw-exchange/exchange.taler-ops.ch/
    var exchangeBaseUrl: String                     // https://exchange.taler-ops.ch/
    var currency: String                            // CHF
    var currencySpec: CurrencySpecification         // .name = "Swiss Francs"... alt_unit_names":{"0":"Fr.","-2":"Rp."}
 //   var restrictions: [AccountRestriction]?         // ["Swiss bank accounts only"] too bad, need to contact server to get this data
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var recommendationReasons: [String]?
}

extension DefaultExchange: Identifiable {
    var id: String { exchangeBaseUrl }
}
// MARK: -
/// A request to list exchanges names for a currency
fileprivate struct ListExchanges: WalletBackendFormattedRequest {
    var operation: String { "listExchanges" }
    func args() -> Args { Args(filterByScope: scope, filterByType: filterByType, filterByExchangeEntryStatus: filterByStatus) }

    var scope: ScopeInfo?
    var filterByType: ExchangeType?
    var filterByStatus: ExchangeEntryStatus?
    struct Args: Encodable {
        var filterByScope: ScopeInfo?
        var filterByType: ExchangeType?
        var filterByExchangeEntryStatus: ExchangeEntryStatus?
    }
    struct Response: Decodable {        // list of known exchanges
        var exchanges: [Exchange]
    }
}

fileprivate struct DefaultExchanges: WalletBackendFormattedRequest {
    var operation: String { "listWithdrawalExchangeCandidates" }
    func args() -> Args { Args(presetOnly: true) }

    struct Args: Encodable {
        var presetOnly: Bool
    }

    struct Response: Decodable {        // list of known exchanges
        var candidates: [DefaultExchange]
    }
}

/// A request to get info for one exchange.
fileprivate struct GetExchangeByUrl: WalletBackendFormattedRequest {
    var operation: String { "getExchangeEntryByUrl" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    typealias Response = Exchange
}

/// A request to update a single exchange.
fileprivate struct UpdateExchange: WalletBackendFormattedRequest {
    var operation: String { "updateExchangeEntry" }
//    func args() -> Args { Args(scopeInfo: scopeInfo) }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, force: force) }

//    var scopeInfo: ScopeInfo
    var exchangeBaseUrl: String
    var force: Bool
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var force: Bool
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}

/// A request to add an exchange.
fileprivate struct AddExchange: WalletBackendFormattedRequest {
    var operation: String { "addExchange" }
    func args() -> Args { Args(uri: uri, allowCompletion: true,
                               progressToken: uri) }
    var uri: String
    struct Args: Encodable {
        var uri: String
        var allowCompletion: Bool
        var progressToken: String
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}

/// A request to delete an exchange.
fileprivate struct DeleteExchange: WalletBackendFormattedRequest {
    var operation: String { "deleteExchange" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, purge: purge) }

    var exchangeBaseUrl: String
    var purge: Bool
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var purge: Bool
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}

/// A request to confirm that a changed exchange key set is legitimate.
/// Needed before a withdrawal can proceed once `unconfirmedKeyChange` is set.
fileprivate struct ConfirmExchangeKeyChange: WalletBackendFormattedRequest {
    var operation: String { "confirmExchangeKeyChange" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, currentMasterPub: currentMasterPub) }

    var exchangeBaseUrl: String
    var currentMasterPub: String
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var currentMasterPub: String
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}
fileprivate struct PurgeExchangeLegacyKeys: WalletBackendFormattedRequest {
    var operation: String { "purgeExchangeLegacyKeys" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, currentMasterPub: currentMasterPub) }

    var exchangeBaseUrl: String
    var currentMasterPub: String
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var currentMasterPub: String
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}
/// A request to get info about a currency
fileprivate struct GetCurrencySpecification: WalletBackendFormattedRequest {
    var operation: String { "getCurrencySpecification" }
    func args() -> Args { Args(scope: scope) }

    var scope: ScopeInfo
    struct Args: Encodable {
        var scope: ScopeInfo
    }
    struct Response: Codable, Sendable {
        let currencySpecification: CurrencySpecification
    }
}
/// A request to make a currency "global"
fileprivate struct AddGlobalCurrency: WalletBackendFormattedRequest {
    var operation: String { "addGlobalCurrencyExchange" }
    func args() -> Args { Args(currency: currency,
                        exchangeBaseUrl: baseUrl,
                      exchangeMasterPub: masterPub) }
    var currency: String
    var baseUrl: String
    var masterPub: String
    struct Args: Encodable {
        var currency: String
        var exchangeBaseUrl: String
        var exchangeMasterPub: String
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}
fileprivate struct RmvGlobalCurrency: WalletBackendFormattedRequest {
    var operation: String { "removeGlobalCurrencyExchange" }
    func args() -> Args { Args(currency: currency,
                        exchangeBaseUrl: baseUrl,
                      exchangeMasterPub: masterPub) }
    var currency: String
    var baseUrl: String
    var masterPub: String
    struct Args: Encodable {
        var currency: String
        var exchangeBaseUrl: String
        var exchangeMasterPub: String
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}
// MARK: -
extension WalletModel {
    /// ask wallet-core for its list of known exchanges
    nonisolated func listExchanges(scope: ScopeInfo?, filterByType: ExchangeType? = nil,
                          filterByStatus: ExchangeEntryStatus? = nil, viewHandles: Bool = false)
      async -> [Exchange] {   // M for MainActor
        do {
            let request = ListExchanges(scope: scope,
                                 filterByType: filterByType,        // .demo, .prod
                               filterByStatus: filterByStatus)      // .used, .preset
            let (response, id) = try await sendRequest(request, viewHandles: viewHandles)
            return response.exchanges
        } catch {
            return []               // empty, but not nil
        }
    }

    /// ask wallet-core for its list of default exchanges   ==> currently only taler-ops.ch
    nonisolated func getDefaultExchanges(viewHandles: Bool = false)
      async -> [DefaultExchange] {     // M for MainActor
        do {
            let request = DefaultExchanges()
            let (response, id) = try await sendRequest(request, viewHandles: viewHandles)
            return response.candidates
        } catch {
            return []               // empty, but not nil
        }
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    nonisolated func getExchangeByUrl(url: String, viewHandles: Bool = false)
      async throws -> Exchange {
        let request = GetExchangeByUrl(exchangeBaseUrl: url)
//            logger.info("query for exchange: \(url, privacy: .public)")
        let (response, id) = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    nonisolated func addExchange(uri: String, viewHandles: Bool = false)
      async throws {
        let request = AddExchange(uri: uri)
        logger.info("adding exchange: \(uri, privacy: .public)")
        let controller = Controller.shared
        controller.progressOperation = request.operation
        controller.progressToken = uri
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    nonisolated func deleteExchange(url: String, purge: Bool = false, viewHandles: Bool = false)
      async throws {
        let request = DeleteExchange(exchangeBaseUrl: url, purge: purge)
        logger.info("deleting exchange: \(url, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    /// ask wallet-core to update an existing exchange by querying it for denominations, fees, and scoped currency info
//    func updateExchange(scopeInfo: ScopeInfo, viewHandles: Bool = false)
    nonisolated func updateExchange(exchangeBaseUrl: String, force: Bool = false, viewHandles: Bool = false)
      async throws  {
        let request = UpdateExchange(exchangeBaseUrl: exchangeBaseUrl, force: force)
        logger.info("updating exchange: \(exchangeBaseUrl, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    /// confirm a changed exchange master key so withdrawals are allowed again
    nonisolated func confirmExchangeKeyChange(exchangeBaseUrl: String, currentMasterPub: String, viewHandles: Bool = false)
      async throws {
        let request = ConfirmExchangeKeyChange(exchangeBaseUrl: exchangeBaseUrl, currentMasterPub: currentMasterPub)
        logger.info("confirming exchange key change: \(exchangeBaseUrl, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func purgeExchangeLegacyKeys(exchangeBaseUrl: String, currentMasterPub: String, viewHandles: Bool = false)
    async throws {
        let request = PurgeExchangeLegacyKeys(exchangeBaseUrl: exchangeBaseUrl, currentMasterPub: currentMasterPub)
        logger.info("purging old exchange keys: \(exchangeBaseUrl, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func getCurrencyInfo(scope: ScopeInfo, viewHandles: Bool = false)
      async throws -> CurrencyInfo {
        let request = GetCurrencySpecification(scope: scope)
        let (response, id) = try await sendRequest(request, viewHandles: viewHandles)
        return CurrencyInfo(specs: response.currencySpecification,
                        formatter: CurrencyFormatter.formatter(currency: scope.currency,
                                                                  specs: response.currencySpecification))
    }

    nonisolated func addGlobalCurrencyExchange(currency: String, baseUrl: String, masterPub: String, viewHandles: Bool = false)
      async throws {
        let request = AddGlobalCurrency(currency: currency, baseUrl: baseUrl, masterPub: masterPub)
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    nonisolated func rmvGlobalCurrencyExchange(currency: String, baseUrl: String, masterPub: String, viewHandles: Bool = false)
      async throws {
        let request = RmvGlobalCurrency(currency: currency, baseUrl: baseUrl, masterPub: masterPub)
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
