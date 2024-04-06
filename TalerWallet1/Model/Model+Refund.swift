/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
/// A request to prepare a refund with an obtained URI
struct StartRefundURIRequest: WalletBackendFormattedRequest {
    func operation() -> String { "startRefundQueryForUri" }
    func args() -> Args { Args(talerRefundUri: talerRefundUri) }

    var talerRefundUri: String

    struct Args: Encodable {
        var talerRefundUri: String
    }

    /// returns the txID of the new refund
    struct Response: Decodable {
        var transactionId: String
    }
}

/// A request to prepare a refund with a transactionID
struct StartRefundQueryRequest: WalletBackendFormattedRequest {
    func operation() -> String { "startRefundQuery" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }

    /// no error means the refunds was successful
    struct Response: Decodable {}
}
// MARK: -
extension WalletModel {
    @MainActor
    func startRefundForUriM(url: String, viewHandles: Bool = false) async throws -> String {
        let request = StartRefundURIRequest(talerRefundUri: url)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.transactionId
    }

    @MainActor
    func startRefundM(transactionId: String, viewHandles: Bool = false) async throws {
        let request = StartRefundQueryRequest(transactionId: transactionId)
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }
}
