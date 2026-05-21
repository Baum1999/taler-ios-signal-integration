/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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

/// Information supplied by the backend describing an error.
struct WalletBackendResponseError: Codable {
    /// Numeric error code defined below (-1..-4)
    var code: Int
    // all other fields are optional:
    var when: Timestamp?
    /// English description of the error code.
    var hint: String?
    /// English diagnostic message that can give details for the instance of the error.
    var message: String?

    var requestUrl: String?
//    var httpStatusCode: Int?
//    var requestMethod: String?

    var errorResponse: TalerErrorDetail?

    var insufficientBalanceDetails: PaymentInsufficientBalanceDetails? = nil
}

struct WalletBackendAbortReason: Codable {
    /// Numeric error code defined below (-1..-4)
    var code: Int
    // all other fields are optional:
    var when: Timestamp?
    /// English description of the error code.
    var hint: String?
    /// English diagnostic message that can give details for the instance of the error.
    var message: String?

    var exchangeResponse: TalerErrorDetail?
}

extension WalletCore {
    static func serializeRequestError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -1, when: Timestamp.now(),
                                          hint: "Could not serialize request.", message: EMPTYSTRING)
    }
    
    static func parseResponseError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -2, when: Timestamp.now(),
                                          hint: "Could not parse response.", message: EMPTYSTRING)
    }
    
    static func parseFailureError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -3, when: Timestamp.now(),
                                          hint: "Could not parse error detail.", message: EMPTYSTRING)
    }

    static func walletError() -> WalletBackendResponseError {
        return WalletBackendResponseError(code: -4, when: Timestamp.now(),
                                          hint: "Error detail.", message: EMPTYSTRING)
    }
}
