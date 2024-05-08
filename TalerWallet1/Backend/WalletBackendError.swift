/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
 */
import Foundation
import taler_swift

/// Errors for `WalletBackend`.
enum WalletBackendError: Error {
    /// An error that prevented the wallet from being initialized occurred.
    case initializationError
    case serializationError
    case deserializationError
    case walletCoreError(WalletBackendResponseError?)
}

struct ErrorResponse: Codable {
    var code: Int
    /// English description of the error code.
    var hint: String

    /// Error details, type depends on `talerErrorCode`.
    var detail: String? = nil
}

/// Information supplied by the backend describing an error.
struct WalletBackendResponseError: Codable {
    /// Numeric error code defined defined in the GANA gnu-taler-error-codes registry.
    var code: Int

    var when: Timestamp?

    /// English description of the error code.
    var hint: String

    var requestUrl: String? = nil

    var httpStatusCode: Int? = nil

    var errorResponse: ErrorResponse? = nil

    /// English diagnostic message that can give details for the instance of the error.
    var message: String? = nil
}

extension WalletCore {
    static func serializeRequestError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -1, when: Timestamp.now(),
                                          hint: "Could not serialize request.", message: "")
    }
    
    static func parseResponseError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -2, when: Timestamp.now(),
                                          hint: "Could not parse response.", message: "")
    }
    
    static func parseFailureError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -3, when: Timestamp.now(),
                                          hint: "Could not parse error detail.", message: "")
    }

    static func walletError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -4, when: Timestamp.now(),
                                          hint: "Error detail.", message: "")
    }
}
