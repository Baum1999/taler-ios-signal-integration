/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
/// The result from wallet-core's ListExchanges
struct Exchange: Codable, Hashable, Identifiable {
    static func == (lhs: Exchange, rhs: Exchange) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl &&
        lhs.exchangeStatus == rhs.exchangeStatus &&
        lhs.permanent == rhs.permanent
    }

    var exchangeBaseUrl: String
    var currency: String?
    var paytoUris: [String]
    var tosStatus: String
    var exchangeStatus: String
    var ageRestrictionOptions: [Int]
    var permanent: Bool
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

struct HTTPError: Codable, Hashable {
    var code: Int
    var requestUrl: String?
    var hint: String
    var requestMethod: String?
    var httpStatusCode: Int?
    var when: Timestamp?
    var stack: String?
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

/// A request to add an exchange.
fileprivate struct AddExchange: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return "addExchange" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}

/// A request to get info about a currency
struct ScopedCurrencyInfo: Decodable {
    var decimalSeparator: String
    var numFractionalDigits: Int        // 0 Yen, 2 €,$, 3 arabic
    var numTinyDigits: Int              // SuperScriptDigits
    var isCurrencyNameLeading: Bool
}

fileprivate struct GetScopedCurrencyInfo: WalletBackendFormattedRequest {
    typealias Response = ScopedCurrencyInfo
    func operation() -> String { return "getScopedCurrencyInfo" }
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

    @MainActor func getScopedCurrencyInfoM(scope: ScopeInfo)
    async throws -> ScopedCurrencyInfo {   // M for MainActor
        let request = GetScopedCurrencyInfo(scope: scope)
        let response = try await sendRequest(request, ASYNCDELAY)
        return response
    }

}
