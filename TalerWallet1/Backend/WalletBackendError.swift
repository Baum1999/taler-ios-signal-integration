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

/// Errors for `WalletBackend`.
enum WalletBackendError: Error {
    /// An error that prevented the wallet from being initialized occurred.
    case initializationError
    case serializationError
    case deserializationError
    case walletCoreError
}

/// Information supplied by the backend describing an error.
struct WalletBackendResponseError: Decodable {
    /// Numeric error code defined defined in the GANA gnu-taler-error-codes registry.
    var talerErrorCode: Int
    
    /// English description of the error code.
    var talerErrorHint: String
    
    /// English diagnostic message that can give details for the instance of the error.
    var message: String
    
    /// Error details, type depends on `talerErrorCode`.
    var details: Data?
}

extension WalletCore {
    static func serializeRequestError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -1, talerErrorHint: "Could not serialize request.", message: "")
    }
    
    static func parseResponseError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -2, talerErrorHint: "Could not parse response.", message: "")
    }
    
    static func parseFailureError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -3, talerErrorHint: "Could not parse error detail.", message: "")
    }
}
