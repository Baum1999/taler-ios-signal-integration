/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import AnyCodable
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

class PendingModel: WalletModel {
    @Published var pendingOperations: [PendingOperation]

    override init(_ symbol: Int = -1) {
        pendingOperations = []                // empty, but not nil
        super.init(symbol)
    }
}
// MARK: -
/// A request to list the backend's currently pending operations.
fileprivate struct GetPendingOperations: WalletBackendFormattedRequest {
    func operation() -> String { return "getPendingOperations" }
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
extension PendingModel {
    @MainActor func updateM()
      async throws {   // M for MainActor
        do {
            let request = GetPendingOperations()
            let response = try await sendRequestM(request, ASYNCDELAY)
            pendingOperations = response.pendingOperations
        }
    }
}

// MARK: -
extension PendingModel {
    private static var models: [PendingModel] = []     // a list of models even though I currently need only one

    static func model() -> PendingModel {
        if PendingModel.models.count > 0 {
            let model = PendingModel.models[0]
            return model
        } else {        // new model
            let model = PendingModel()
            PendingModel.models.append(model)
            return model
        }
    }
}
