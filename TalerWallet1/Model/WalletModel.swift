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
import SymLog

fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

/// The "virtual" base class for all models
class WalletModel: ObservableObject {
    static func className() -> String {"\(self)"}
    var symLog: SymLogC?
    var walletCore: WalletCore

    @Published var loading: Bool = false                // update view

    init(walletCore: WalletCore) {
        self.symLog = SymLogC(funcName: Self.className())
        self.walletCore = walletCore
    }

    @MainActor func sendRequest<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
      async throws -> T.Response {
        loading = true                                  // enter progressView
        do {
            symLog?.log("sending: \(request)")
            let (response, id) = try await walletCore.sendFormattedRequest(request: request)
            let asyncDelay: UInt = delay > 0 ? delay : UInt(ASYNCDELAY)
            if asyncDelay > 0 {     // test LoadingView, sleep some seconds
                symLog?.log("received: (\(id)), going to sleep for \(asyncDelay) seconds...")
                try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(asyncDelay))
                symLog?.log("waking up again after \(asyncDelay) seconds, will deliver \(response)")
            } else {
                symLog?.log("received: \(response)")
            }
            loading = false                             // exit progressView
            return response
        } catch {
            throw error
        }
    }

}
