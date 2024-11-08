/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AnyCodable
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

// MARK: -
/// A request to list the backend's currently pending operations.
fileprivate struct GetPendingOperations: WalletBackendFormattedRequest {
    func operation() -> String { "getPendingOperations" }
    func args() -> Args { Args() }

    struct Args: Encodable {}

    struct Response: Decodable {
        var pendingOperations: [PendingOperation]
    }
}
// MARK: -
struct PendingOperation: Codable, Hashable {
    var type: String
    var exchangeBaseUrl: String?
    var id: String
    var isLongpolling: Bool
    var givesLifeness: Bool
    var isDue: Bool
    var timestampDue: Timestamp

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(exchangeBaseUrl)
        hasher.combine(id)
        hasher.combine(isLongpolling)
        hasher.combine(givesLifeness)
        hasher.combine(isDue)
        hasher.combine(timestampDue)
    }
}
// MARK: -
extension WalletModel {
    nonisolated func getPendingOperations4711(viewHandles: Bool = false)
      async throws -> [PendingOperation] {   // M for MainActor
        let request = GetPendingOperations()
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
        return response.pendingOperations
    }
}
