/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
    case initialUpdate = "initial(update)"
    case suspended
    case failed
    case outdatedUpdate = "outdated(update)"
    case ready
    case readyUpdate = "ready(update)"
}
// MARK: -
/// The result from wallet-core's ListExchanges
struct Exchange: Codable, Hashable, Identifiable {
    static func == (lhs: Exchange, rhs: Exchange) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl
        &&     lhs.tosStatus == rhs.tosStatus
//        &&     lhs.exchangeStatus == rhs.exchangeStatus                         // deprecated
        &&     lhs.exchangeEntryStatus == rhs.exchangeEntryStatus
        &&     lhs.exchangeUpdateStatus == rhs.exchangeUpdateStatus
    }

    var exchangeBaseUrl: String
    // deprecated, use scopeInfo
    var currency: String?           // TODO: remove this
    var scopeInfo: ScopeInfo?
    var paytoUris: [String]
    var tosStatus: ExchangeTosStatus
    // deprecated, use EntryStatus + UpdateStatus
//    var exchangeStatus: String?
    var exchangeEntryStatus: ExchangeEntryStatus
    var exchangeUpdateStatus: ExchangeUpdateStatus
    var ageRestrictionOptions: [Int]
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
    func args() -> Args { Args(scopeInfo: scopeInfo) }

    var scopeInfo: ScopeInfo

    struct Args: Encodable {
        var scopeInfo: ScopeInfo
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
    typealias Response = CurrencySpecification2
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
    @MainActor func listExchangesForScopedCurrencyM(scope: ScopeInfo)
      async -> [ExchangeUrlItem] {            // M for MainActor
        do {
            let request = ListExchangesForScopedCurrency(scope: scope)
            let response = try await sendRequest(request, ASYNCDELAY)
            return response.exchanges
        } catch {
            return []               // empty, but not nil
        }
    }

    /// ask wallet-core for its list of known exchanges
    @MainActor func listExchangesM()
      async -> [Exchange] {   // M for MainActor
        do {
            let request = ListExchanges()
            let response = try await sendRequest(request, ASYNCDELAY)
            return response.exchanges
        } catch {
            return []               // empty, but not nil
        }
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    func getExchangeByUrl(url: String)
      async -> Exchange? {
        do {
            let request = GetExchangeByUrl(exchangeBaseUrl: url)
            logger.info("query for exchange: \(url, privacy: .public)")
            let response = try await sendRequest(request)
            return response
        } catch {
            return nil
        }
    }

    /// add a new exchange with URL to the wallet's list of known exchanges
    func addExchange(url: String)
    async throws {
        let request = AddExchange(exchangeBaseUrl: url)
        logger.info("adding exchange: \(url, privacy: .public)")
        _ = try await sendRequest(request)
    }

    /// ask wallet-core to update an existing exchange by querying it for denominations, fees, and scoped currency info
    func updateExchange(scopeInfo: ScopeInfo)
      async throws  {
        let request = UpdateExchange(scopeInfo: scopeInfo)
        logger.info("updating exchange for: \(scopeInfo.currency, privacy: .public)")
        _ = try await sendRequest(request)
    }

    func getCurrencyInfo(scope: ScopeInfo, delay: UInt = 0)
      async throws -> CurrencyInfo {
        let request = GetCurrencySpecification(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY + delay)
        return CurrencyInfo(scope: scope, specs: response.currencySpecification,
                        formatter: CurrencyFormatter.formatter(scope: scope,
                                                               specs: response.currencySpecification))
    }

}
