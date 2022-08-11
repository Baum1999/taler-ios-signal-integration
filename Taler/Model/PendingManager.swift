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

class PendingManager: ObservableObject {
    var backend: WalletBackend
    
    @Published var loading: Bool
    @Published var items: [String]?
    
    init(_backend: WalletBackend) {
        self.backend = _backend
        self.loading = false
        self.items = nil
    }
    
    func update() {
        let req = WalletBackendPendingRequest()
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead.
            DispatchQueue.main.async {
                self.loading = false
                if let x = response {
                    self.items = x.pendingOperations.map({ op in
                        let encoded = try! JSONEncoder().encode(op)
                        let str = String(data: encoded, encoding: .utf8)!
                        return str
                    })
                }
            }
        }
        self.loading = true
    }
}
