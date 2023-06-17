/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import SymLog

fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging


// MARK: -
/// The "virtual" base class for all models
class WalletModel {
    static func className() -> String {"\(self)"}
    var symLog: SymLogC?

    init(_ symbol: Int) {                               // init with 0 to disable logging for this class
        self.symLog = SymLogC(symbol == 0 ? 0 : -1, funcName: Self.className())
    }

    func sendRequest<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
    async throws -> T.Response {    // T for any Thread
        let sendTime = Date.now
        do {
            symLog?.log("sending: \(request)")
            let (response, id) = try await WalletCore.shared.sendFormattedRequest(request: request)
            let timeUsed = Date.now - sendTime
            let asyncDelay: UInt = delay > 0 ? delay : UInt(ASYNCDELAY)
            if asyncDelay > 0 {     // test LoadingView, sleep some seconds
                symLog?.log("received: (\(id)) after \(timeUsed.milliseconds) ms, going to sleep for \(asyncDelay) seconds...")
                try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(asyncDelay))
                symLog?.log("(\(id)) waking up again after \(asyncDelay) seconds, will deliver \(response)")
            } else {
                symLog?.log("received: (\(id)) after \(timeUsed.milliseconds) ms, \(response)")
            }
            return response
        } catch {       // rethrows
            let timeUsed = Date.now - sendTime
            symLog?.log("Yikes❗️ \(request.operation()) failed after \(timeUsed.milliseconds) ms")
            throw error
        }
    }

    func getTransactionByIdT(_ transactionId: String)
      async throws -> Transaction {              // T for any Thread
        // might be called from a background thread itself
        let request = GetTransactionById(transactionId: transactionId)
        return try await sendRequest(request, ASYNCDELAY)
    }
    /// get the specified transaction from Wallet-Core. No networking involved
    @MainActor func getTransactionByIdM(_ transactionId: String)
    async throws -> Transaction {                // M for MainActor
        return try await getTransactionByIdT(transactionId)      // call GetTransactionById on main thread
    }
}
// MARK: -
/// A request to get a wallet transaction by ID.
fileprivate struct GetTransactionById: WalletBackendFormattedRequest {
    typealias Response = Transaction
    func operation() -> String { return "getTransactionById" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }
}

