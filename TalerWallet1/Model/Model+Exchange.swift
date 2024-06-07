/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

struct ExchangeError: Codable, Hashable {
    var error: HTTPError
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
    var lastUpdateTimestamp: Timestamp?
    var lastUpdateErrorInfo: ExchangeError?

    var id: String { exchangeBaseUrl }
    var name: String? {
        if let url = URL(string: exchangeBaseUrl) {
            if let host = url.host {
                return host
            }
        }
        return nil
    }
}

struct ExchangeUrlItem: Codable, Hashable, Identifiable {
    var exchangeBaseUrl: String
    var id: String { exchangeBaseUrl }
}
// MARK: -
/// A request to list exchanges names for a currency
fileprivate struct ListExchangesForScopedCurrency: WalletBackendFormattedRequest {
    func operation() -> String { "listExchangesForScopedCurrency" }
    func args() -> Args { Args(scope: scope) }

    var scope: ScopeInfo

    struct Args: Encodable {
        var scope: ScopeInfo
    }
    struct Response: Decodable, Sendable {
        var exchanges: [ExchangeUrlItem]              // list of Exchange names
    }
}

/// A request to list exchanges.
fileprivate struct ListExchanges: WalletBackendFormattedRequest {
    func operation() -> String { "listExchanges" }
    func args() -> Args { Args() }

    struct Args: Encodable {}           // no arguments needed

    struct Response: Decodable {        // list of known exchanges
        var exchanges: [Exchange]
    }
}

/// A request to get info for one exchange.
fileprivate struct GetExchangeByUrl: WalletBackendFormattedRequest {
    typealias Response = Exchange
    func operation() -> String { "getExchangeEntryByUrl" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}

/// A request to update a single exchange.
fileprivate struct UpdateExchange: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "updateExchangeEntry" }
//    func args() -> Args { Args(scopeInfo: scopeInfo) }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

//    var scopeInfo: ScopeInfo
    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}

/// A request to add an exchange.
fileprivate struct AddExchange: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "addExchange" }     // addExchangeEntry
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}

/// A request to get info about a currency
fileprivate struct GetCurrencySpecification: WalletBackendFormattedRequest {
    struct Response: Codable, Sendable {
        let currencySpecification: CurrencySpecification
    }
    func operation() -> String { "getCurrencySpecification" }
    func args() -> Args { Args(scope: scope) }

    var scope: ScopeInfo

    struct Args: Encodable {
        var scope: ScopeInfo
    }
}
// MARK: -
extension WalletModel {
    /// ask wallet-core for its list of known exchanges
    @MainActor func listExchangesForScopedCurrencyM(scope: ScopeInfo, viewHandles: Bool = false)
      async -> [ExchangeUrlItem] {            // M for MainActor
        do {
            let request = ListExchangesForScopedCurrency(scope: scope)
            let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
            return response.exchanges
        } catch {
            return []               // empty, but not nil
        }
    }

    /// ask wallet-core for its list of known exchanges
    @MainActor func listExchangesM(devMode: Bool = false, viewHandles: Bool = false)
      async throws -> [Exchange] {   // M for MainActor
        let request = ListExchanges()
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.exchanges
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    func getExchangeByUrl(url: String, viewHandles: Bool = false)
      async throws -> Exchange {
        let request = GetExchangeByUrl(exchangeBaseUrl: url)
//            logger.info("query for exchange: \(url, privacy: .public)")
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    func addExchange(url: String, viewHandles: Bool = false)
    async throws {
        let request = AddExchange(exchangeBaseUrl: url)
        logger.info("adding exchange: \(url, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    /// ask wallet-core to update an existing exchange by querying it for denominations, fees, and scoped currency info
//    func updateExchange(scopeInfo: ScopeInfo)
//    func updateExchange(scopeInfo: ScopeInfo, viewHandles: Bool = false)
    func updateExchange(exchangeBaseUrl: String, viewHandles: Bool = false)
      async throws  {
//        let request = UpdateExchange(scopeInfo: scopeInfo)
        let request = UpdateExchange(exchangeBaseUrl: exchangeBaseUrl)
//        logger.info("updating exchange for: \(scopeInfo.currency, privacy: .public)")
        logger.info("updating exchange: \(exchangeBaseUrl, privacy: .public)")
        _ = try await sendRequest(request, viewHandles: viewHandles)
    }

    @MainActor
    func getCurrencyInfoM(scope: ScopeInfo, delay: UInt = 0, viewHandles: Bool = false)
      async throws -> CurrencyInfo {
        let request = GetCurrencySpecification(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY + delay, viewHandles: viewHandles)
        return CurrencyInfo(scope: scope, specs: response.currencySpecification,
                        formatter: CurrencyFormatter.formatter(scope: scope,
                                                               specs: response.currencySpecification))
    }

}
