/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation

extension StringProtocol {

    func trimURL() -> String {
        if let url = URL(string: String(self)) {
            if let host = url.host {
                return host
            }
        }
        return String(self)
    }
}
