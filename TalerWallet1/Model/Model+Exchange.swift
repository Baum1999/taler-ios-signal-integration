/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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

enum ExchangeEntryStatus: String, Codable {
    case preset
    case ephemeral
    case used
}

enum ExchangeUpdateStatus: String, Codable {
    case initial
    case initialUpdate = "initial-update"
    case suspended
    case failed
    case outdatedUpdate = "outdated-update"
    case ready
    case readyUpdate = "ready-update"
    case unavailable
    case unavailableUpdate = "unavailable-update"

    var localized: String {
        switch self {
            case .initial:           String(localized: "Initial")
            case .initialUpdate:     String(localized: "Initial update")
            case .suspended:         String(localized: "Suspended")
            case .failed:            String(localized: "Failed")
            case .outdatedUpdate:    String(localized: "Outdated update")
            case .ready:             String(localized: "Ready")
            case .readyUpdate:       String(localized: "Ready update")
            case .unavailable:       String(localized: "Unavailable")
            case .unavailableUpdate: String(localized: "Unavailable update")
        }
    }
}

struct ExchangeState: Codable, Hashable {
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var tosStatus: ExchangeTosStatus
}

struct ExchangeTransition: Codable {             // Notification
    enum TransitionType: String, Codable {
        case transition = "exchange-state-transition"
    }
    var type: TransitionType
    var exchangeBaseUrl: String
    var oldExchangeState: ExchangeState
    var newExchangeState: ExchangeState
}

enum BankDialect: Codable, Hashable {
    case gls
    case unknown(value: String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let status = try? container.decode(String.self)
        switch status {
            case "gls": self = .gls
            default:
                self = .unknown(value: status ?? "unknown")
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
    var masterPub: String?
    var scopeInfo: ScopeInfo
    var paytoUris: [String]
    var tosStatus: ExchangeTosStatus
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var peerPaymentsDisabled: Bool?
    var noFees: Bool?
    var ageRestrictionOptions: [Int]
    var bankComplianceLanguage: BankDialect?
    var lastUpdateTimestamp: Timestamp?
    var lastUpdateErrorInfo: OperationErrorInfo?

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
/// A request to list exchanges names for a currency
fileprivate struct ListExchanges: WalletBackendFormattedRequest {
    func operation() -> String { "listExchanges" }
    func args() -> Args { Args(filterByScope: scope, filterByExchangeEntryStatus: filterByStatus) }

    var scope: ScopeInfo?
    var filterByStatus: ExchangeEntryStatus?
    struct Args: Encodable {
        var filterByScope: ScopeInfo?
        var filterByExchangeEntryStatus: ExchangeEntryStatus?
    }
    struct Response: Decodable {        // list of known exchanges
        var exchanges: [Exchange]
    }
}

/// A request to get info for one exchange.
fileprivate struct GetExchangeByUrl: WalletBackendFormattedRequest {
    func operation() -> String { "getExchangeEntryByUrl" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
    typealias Response = Exchange
}

/// A request to update a single exchange.
fileprivate struct UpdateExchange: WalletBackendFormattedRequest {
    func operation() -> String { "updateExchangeEntry" }
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
    func operation() -> String { "addExchange" }
    func args() -> Args { Args(uri: uri, allowCompletion: true) }

    var uri: String
    struct Args: Encodable {
        var uri: String
        var allowCompletion: Bool
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}

/// A request to delete an exchange.
fileprivate struct DeleteExchange: WalletBackendFormattedRequest {
    func operation() -> String { "deleteExchange" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl, purge: purge) }

    var exchangeBaseUrl: String
    var purge: Bool
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var purge: Bool
    }
    struct Response: Decodable {}   // no result - getting no error back means success
}

/// A request to get info about a currency
fileprivate struct GetCurrencySpecification: WalletBackendFormattedRequest {
    func operation() -> String { "getCurrencySpecification" }
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
    func operation() -> String { "addGlobalCurrencyExchange" }
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
    func operation() -> String { "removeGlobalCurrencyExchange" }
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
    nonisolated func listExchanges(scope: ScopeInfo?, filterByStatus: ExchangeEntryStatus? = nil, viewHandles: Bool = false)
      async -> [Exchange] {   // M for MainActor
        do {
            let request = ListExchanges(scope: scope, filterByStatus: filterByStatus)    // .used, .preset
            let response = try await sendRequest(request, viewHandles: viewHandles)
            return response.exchanges
        } catch {
            return []               // empty, but not nil
        }
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    nonisolated func getExchangeByUrl(url: String, viewHandles: Bool = false)
      async throws -> Exchange {
        let request = GetExchangeByUrl(exchangeBaseUrl: url)
//            logger.info("query for exchange: \(url, privacy: .public)")
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    nonisolated func addExchange(uri: String, viewHandles: Bool = false)
      async throws {
        let request = AddExchange(uri: uri)
        logger.info("adding exchange: \(uri, privacy: .public)")
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

    nonisolated func getCurrencyInfo(scope: ScopeInfo, viewHandles: Bool = false)
      async throws -> CurrencyInfo {
        let request = GetCurrencySpecification(scope: scope)
        let response = try await sendRequest(request, viewHandles: viewHandles)
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
