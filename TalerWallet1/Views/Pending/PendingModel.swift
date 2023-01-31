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
import AnyCodable
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

class PendingModel: WalletModel {
    @Published var pendingOperations: [PendingOperation]?
}
// MARK: -
/// A request to list the backend's currently pending operations.
fileprivate struct GetPendingOperations: WalletBackendFormattedRequest {
    func operation() -> String { return "getPendingOperations" }
    func args() -> Args { Args() }

    struct Args: Encodable {}

    struct Response: Decodable {
        var pendingOperations: [PendingOperation]
    }
}
// MARK: -
struct PendingOperation: Codable, Hashable {
    var type: String
    var exchangeBaseUrl: String
    var id: String
    var isLongpolling: Bool
    var givesLifeness: Bool
    var isDue: Bool
    var timestampDue: Timestamp

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(exchangeBaseUrl)
        hasher.combine(id)
        hasher.combine(isLongpolling)
        hasher.combine(givesLifeness)
        hasher.combine(isDue)
        hasher.combine(timestampDue)
    }

}
//let pending1 = ["type": "exchange-update",
//                "exchangeBaseUrl": "https://exchange.demo.taler.net/",
//                "id": "exchange-update:https://exchange.demo.taler.net/",
//                "timestampDue": ["t_ms": 1669931055000],
//                "isDue": false,
//                "isLongpolling": false,
//                "givesLifeness": false] as [String : Any]
//
//let pending2 = ["type": "exchange-check-refresh",
//                "exchangeBaseUrl": "https://exchange.demo.taler.net/",
//                "id": "exchange-update:https://exchange.demo.taler.net/",
//                "timestampDue": ["t_ms": 1670013862000],
//                "isDue": false,
//                "isLongpolling": false,
//                "givesLifeness": false] as [String : Any]
// MARK: -
extension PendingModel {
    @MainActor func update() async throws {
        do {
            let request = GetPendingOperations()
            let response = try await sendRequest(request, ASYNCDELAY)
            pendingOperations = response.pendingOperations
        }
    }
}
