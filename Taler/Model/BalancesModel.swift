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
    enum State {
        case begin
        case loading
        case loaded([Balance])
    }
    
    var backend: WalletBackend
    @Published var state: State
    
    init(backend: WalletBackend) {
        self.backend = backend
        self.state = .begin
    }
    
    func getBalances() {
        self.state = .loading
        let req = WalletBackendGetBalancesRequest()
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                if let res = response {
                    self.state = .loaded(res.balances)
                } else {
                    // TODO: Handle error.
                    self.state = .begin
                }
            }
        }
    }
}
