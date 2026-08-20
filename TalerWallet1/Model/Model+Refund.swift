/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

// MARK: -
/// A request to prepare a refund with an obtained URI
struct StartRefundURIRequest: WalletBackendFormattedRequest {
    var operation: String { "startRefundQueryForUri" }
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
    var operation: String { "startRefundQuery" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }

    /// No error means the background refund query was started
    /// the actual outcome arrives later via notification
    struct Response: Decodable {}
}
// MARK: -
extension WalletModel {
    nonisolated func startRefundForUri(url: String, viewHandles: Bool = false) async throws -> String {
        let request = StartRefundURIRequest(talerRefundUri: url)
        let response = try await sendRequest(request, viewHandles: viewHandles)
        return response.transactionId
    }

    nonisolated func startRefund4711(transactionId: String, viewHandles: Bool = false) async throws {
        let request = StartRefundQueryRequest(transactionId: transactionId)
        let _ = try await sendRequest(request, viewHandles: viewHandles)
    }
}
