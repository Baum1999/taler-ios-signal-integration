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

typealias ExchangeItem = WalletBackendListExchanges.ExchangeListItem

class ExchangeManager: ObservableObject {
    var backend: WalletBackend
    
    @Published var loading: Bool
    @Published var exchanges: [ExchangeItem]?
    
    init(_backend: WalletBackend) {
        self.backend = _backend
        self.loading = false
        self.exchanges = nil
    }
    
    func updateList() {
        let listRequest = WalletBackendListExchanges()
        backend.sendFormattedRequest(request: listRequest) { response, err in
            // TODO: Use Combine instead.
            DispatchQueue.main.async {
                self.loading = false
                if let result = response {
                    self.exchanges = result.exchanges
                } else {
                    // TODO: Show error.
                }
            }
        }
        self.loading = true
    }
    
    func add(url: String) {
        let addRequest = WalletBackendAddExchangeRequest(exchangeBaseUrl: url)
        backend.sendFormattedRequest(request: addRequest) { response, err in
            // TODO: Use Combine instead.
            DispatchQueue.main.async {
                self.loading = false
                if let _ = response {
                    self.updateList()
                } else {
                    // TODO: Show error.
                }
            }
        }
        self.loading = true
    }
}
