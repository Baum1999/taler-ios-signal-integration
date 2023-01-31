/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

class ExchangeModel: WalletModel {
    @Published var exchanges: [Exchange]?
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
    func operation() -> String { return "addExchange" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
    }

    struct Response: Decodable {}
}
// MARK: -
struct Exchange: Codable, Hashable {
    static func == (lhs: Exchange, rhs: Exchange) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl &&
        lhs.exchangeStatus == rhs.exchangeStatus &&
        lhs.permanent == rhs.permanent
    }

    var exchangeBaseUrl: String
    var currency: String?
    var tosStatus: String
    var paytoUris: [String]
    var exchangeStatus: String
    var permanent: Bool
    var ageRestrictionOptions: [Int]
    var lastUpdateErrorInfo: ExchangeError?

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
    var requestUrl: String
    var hint: String
    var requestMethod: String
    var httpStatusCode: Int?
}

// MARK: -
extension ExchangeModel {
    /// ask wallet-core for its list of known exchanges
    @MainActor func updateList() async throws {
        do {
            let request = ListExchanges()
            let response = try await sendRequest(request, ASYNCDELAY)
            exchanges = response.exchanges              // trigger view update in ExchangeListView
        } catch { // TODO: Error
            symLog?.log(error.localizedDescription)
            throw error
        }
    }

    /// add a new exchange with URL to wallet's list of known exchanges
    func add(url: String) async throws  {
        do {
            symLog?.log("adding exchange: \(url)")       // TODO: notice
            let request = AddExchange(exchangeBaseUrl: url)
            _ = try await sendRequest(request)
            symLog?.log("added exchange: \(url)")
            try await updateList()
        } catch { // TODO: Error
            symLog?.log(error.localizedDescription)
            throw error
        }
    }
}
