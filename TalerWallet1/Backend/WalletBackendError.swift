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

struct ErrorResponse: Codable {
    var code: Int
    /// English description of the error code.
    var hint: String

    /// Error details, type depends on `talerErrorCode`.
    var detail: String? = nil
}


struct InsufficientBalanceDetailsPerExchange: Codable {
    var balanceAvailable: Amount
    var balanceMaterial: Amount
    var balanceExchangeDepositable: Amount
    var balanceAgeAcceptable: Amount
    var balanceReceiverAcceptable: Amount
    var balanceReceiverDepositable: Amount
    var maxEffectiveSpendAmount: Amount
    /// Exchange doesn't have global fees configured for the relevant year, p2p payments aren't possible.
    var missingGlobalFees: Bool
}

///  Detailed reason for why the wallet's balance is insufficient.
struct PaymentInsufficientBalanceDetails: Codable {
    /// Amount requested by the merchant.
    var amountRequested: Amount
    /// Balance of type "available" (see balance.ts for definition).
    var balanceAvailable: Amount
    /// Balance of type "material" (see balance.ts for definition).
    var balanceMaterial: Amount
    /// Balance of type "age-acceptable" (see balance.ts for definition).
    var balanceAgeAcceptable: Amount
    /// Balance of type "merchant-acceptable" (see balance.ts for definition).
    var balanceReceiverAcceptable: Amount
    /// Balance of type ...
    var balanceReceiverDepositable: Amount
    var balanceExchangeDepositable: Amount
    /// Maximum effective amount that the wallet can spend, when all fees are paid by the wallet.
    var maxEffectiveSpendAmount: Amount
    var perExchange: [String : InsufficientBalanceDetailsPerExchange]
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

    var insufficientBalanceDetails: PaymentInsufficientBalanceDetails? = nil
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
