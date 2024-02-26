/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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
struct WalletBackendResponseError: Codable {
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

    static func walletError() -> WalletBackendResponseError {
        return WalletBackendResponseError(talerErrorCode: -4, talerErrorHint: "Error detail.", message: "")
    }
}
