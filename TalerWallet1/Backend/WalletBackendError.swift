/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
 */
import Foundation

/// Errors for `WalletBackend`.
enum WalletBackendError: Error {
    /// An error that prevented the wallet from being initialized occurred.
    case initializationError
    case serializationError
    case deserializationError
    case walletCoreError(WalletBackendResponseError?)
}

/// Information supplied by the backend describing an error.
struct WalletBackendResponseError: Codable {
    /// Numeric error code defined defined in the GANA gnu-taler-error-codes registry.
    var code: Int
    
    /// English description of the error code.
    var hint: String
    
    /// English diagnostic message that can give details for the instance of the error.
    var message: String? = nil

    /// Error details, type depends on `talerErrorCode`.
    var details: Data? = nil
}

extension WalletCore {
    static func serializeRequestError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -1, hint: "Could not serialize request.", message: "")
    }
    
    static func parseResponseError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -2, hint: "Could not parse response.", message: "")
    }
    
    static func parseFailureError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -3, hint: "Could not parse error detail.", message: "")
    }

    static func walletError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -4, hint: "Error detail.", message: "")
    }
}
