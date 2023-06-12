/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import SymLog

fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging


// MARK: -
/// The "virtual" base class for all models
class WalletModel: ObservableObject {
    static func className() -> String {"\(self)"}
    var symLog: SymLogC?

    @Published var loading: Bool = false                // update view

    init(_ symbol: Int) {                               // init with 0 to disable logging for this class
        self.symLog = SymLogC(symbol == 0 ? 0 : -1, funcName: Self.className())
    }

    @MainActor func sendRequestM<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
      async throws -> T.Response {  // M for MainActor
        loading = true                                  // enter progressView
        do {
            let response = try await sendRequestT(request, delay)
            loading = false                             // exit progressView
            return response
        } catch {       // rethrows
            loading = false                             // exit progressView
            throw error
        }
    }

    func sendRequestT<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
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

    func getTransactionById(transactionId: String) async throws -> Transaction {        // might be called from a background thread itself
        return try await getTransactionByIdM(transactionId: transactionId)      // call deleteTransactionM on main thread
    }
    /// get the specified transaction from Wallet-Core. No networking involved
    @MainActor func getTransactionByIdM(transactionId: String)
    async throws -> Transaction {                // M for MainActor
        do {
            let request = GetTransactionById(transactionId: transactionId)
            let response = try await sendRequestT(request, ASYNCDELAY)
            return response
        } catch {       // rethrows
            throw error
        }
    }
}
// MARK: -
/// A request to get a wallet transaction by ID.
struct GetTransactionById: WalletBackendFormattedRequest {
    typealias Response = Transaction
    func operation() -> String { return "getTransactionById" }
    func args() -> Args { return Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }
}

