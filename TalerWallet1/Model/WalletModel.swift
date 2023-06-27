/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import SymLog
import os.log

fileprivate let DATABASE = "talerwalletdb-v30"
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging


// MARK: -
/// The "virtual" base class for all models
class WalletModel: ObservableObject {
    public static let shared = WalletModel(0)
    static func className() -> String {"\(self)"}
    var symLog: SymLogC?

    init(_ symbol: Int) {                               // init with 0 to disable logging for this class
        self.symLog = SymLogC(symbol == 0 ? 0 : -1, funcName: Self.className())
    }
    let logger = Logger (subsystem: "net.taler.gnu", category: "WalletModel")

    func sendRequest<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
      async throws -> T.Response {    // T for any Thread
        logger.log("sending: \(request.operation(), privacy: .public)")
        let sendTime = Date.now
        do {
            let (response, id) = try await WalletCore.shared.sendFormattedRequest(request: request)
            let timeUsed = Date.now - sendTime
            logger.log("received: \(request.operation(), privacy: .public) (\(id, privacy: .public)) after \(timeUsed.milliseconds, privacy: .public) ms")
            let asyncDelay: UInt = delay > 0 ? delay : UInt(ASYNCDELAY)
            if asyncDelay > 0 {     // test LoadingView, sleep some seconds
                try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(asyncDelay))
            }
            return response
        } catch {       // rethrows
            let timeUsed = Date.now - sendTime
            logger.error("\(request.operation(), privacy: .public) failed after \(timeUsed.milliseconds, privacy: .public) ms\n\(error)")
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
// MARK: -
/// The info returned from Wallet-core init
struct VersionInfo: Decodable {
    var hash: String
    var version: String
    var exchange: String
    var merchant: String
    var bank: String
    var devMode: Bool
}
// MARK: -
///  A request to initialize Wallet-core
fileprivate struct InitRequest: WalletBackendFormattedRequest {
    func operation() -> String { return "init" }
    func args() -> Args {
        return Args(persistentStoragePath: persistentStoragePath,
//                       cryptoWorkerType: "sync",
                                 logLevel: "info") // trace, info, warn, error, none
    }

    struct Args: Encodable {
        var persistentStoragePath: String
//        var cryptoWorkerType: String
        var logLevel: String
    }

    var persistentStoragePath: String

    struct Response: Decodable {
        var versionInfo: VersionInfo
    }
}
// MARK: -
extension WalletModel {
    /// initalize Wallet-Core. Will do networking
    func initWalletCoreT() async throws -> VersionInfo {
                    // T for any Thread
        let docPath = try docPath()
        let request = InitRequest(persistentStoragePath: docPath)
        let response = try await sendRequest(request, 0)    // no Delay
        return response.versionInfo
    }

    private func docPath () throws -> String {
        let documentUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if (documentUrls.count > 0) {
            var storageDir = documentUrls[0]
            storageDir.appendPathComponent(DATABASE, isDirectory: false)
            storageDir.appendPathExtension("json")
            let docPath = storageDir.path
            logger.debug("\(docPath)")
            return docPath
        } else {    // should never happen
            logger.error("documentURLs empty")
            throw WalletBackendError.initializationError
        }
    }
}
