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

class BalancesModel: ObservableObject {
    var backend: WalletBackend
    
    @Published var loading: Bool = false
    @Published var balances: [Balance]?
    
    init(backend: WalletBackend) {
        self.backend = backend
    }
    
    func getBalances() {
        self.loading = true
        let req = WalletBackendGetBalancesRequest()
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                self.loading = false
                if let res = response {
                    self.balances = res.balances
                } else {
                    // TODO: Handle error.
                }
            }
        }
    }
    
    func getTransactionsModel() -> TransactionsModel {
        return TransactionsModel(backend: self.backend, currency: nil)
    }
}
