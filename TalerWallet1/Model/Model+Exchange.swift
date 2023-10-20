/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

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
        &&     lhs.exchangeStatus == rhs.exchangeStatus                         // deprecated
        &&     lhs.exchangeEntryStatus == rhs.exchangeEntryStatus
        &&     lhs.exchangeUpdateStatus == rhs.exchangeUpdateStatus
    }

    var exchangeBaseUrl: String
    var currency: String?
    var paytoUris: [String]
    var tosStatus: ExchangeTosStatus
    var exchangeStatus: String?                                                 // deprecated
    var exchangeEntryStatus: ExchangeEntryStatus?                   // new, but not yet deployed in demo.taler.net
    var exchangeUpdateStatus: ExchangeUpdateStatus?                 // new, but not yet deployed in demo.taler.net
    var ageRestrictionOptions: [Int]
    var lastUpdateErrorInfo: ExchangeError?

    var id: String {
        exchangeBaseUrl
    }
    var name: String? {
        if let url = URL(string: exchangeBaseUrl) {
            if let host = url.host {
                return host
            }
        }
        return nil
    }
}

struct ExchangeError: Codable, Hashable {
    var error: HTTPError
}

// MARK: -
/// A request to list exchanges.
fileprivate struct ListExchanges: WalletBackendFormattedRequest {
    func operation() -> String { return "listExchanges" }
    func args() -> Args { return Args() }

    struct Args: Encodable {}           // no arguments needed

    struct Response: Decodable {        // list of known exchanges
        var exchanges: [Exchange]
    }
}

/// A request to update a single exchange.
fileprivate struct UpdateExchange: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "updateExchangeEntry" }
    func args() -> Args { return Args(scopeInfo: scopeInfo) }

    var scopeInfo: ScopeInfo

    struct Args: Encodable {
        var scopeInfo: ScopeInfo
    }
}

/// A request to add an exchange.
fileprivate struct AddExchange: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "addExchange" }     // addExchangeEntry
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}

/// A request to get info about a currency
fileprivate struct GetCurrencySpecification: WalletBackendFormattedRequest {
    typealias Response = CurrencySpecification
    func operation() -> String { return "getCurrencySpecification" }
    func args() -> Args { return Args(scope: scope) }

    var scope: ScopeInfo

    struct Args: Encodable {
        var scope: ScopeInfo
    }
}
// MARK: -
extension WalletModel {
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
    func addExchange(url: String)
      async throws  {
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

    @MainActor func getCurrencySpecificationM(scope: ScopeInfo)
      async throws -> CurrencySpecification {   // M for MainActor
        let request = GetCurrencySpecification(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }

}
