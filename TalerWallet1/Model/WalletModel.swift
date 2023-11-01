/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
import os.log

fileprivate let DATABASE = "talerwalletdb-v30"
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

struct HTTPError: Codable, Hashable {
    var code: Int
    var requestUrl: String?
    var hint: String
    var requestMethod: String?
    var httpStatusCode: Int?
    var when: Timestamp?
    var stack: String?
}
// MARK: -
/// Communicate with wallet-core
class WalletModel: ObservableObject {
    public static let shared = WalletModel()
    let logger = Logger(subsystem: "net.taler.gnu", category: "WalletModel")
    let semaphore = AsyncSemaphore(value: 1)
    var cachedBalances: [Balance]? = nil

    func sendRequest<T: WalletBackendFormattedRequest> (_ request: T, _ delay: UInt = 0)
      async throws -> T.Response {    // T for any Thread
#if !DEBUG
        logger.log("sending: \(request.operation(), privacy: .public)")
#endif
        let sendTime = Date.now
        do {
            let (response, id) = try await WalletCore.shared.sendFormattedRequest(request)
#if !DEBUG
            let timeUsed = Date.now - sendTime
            logger.log("received: \(request.operation(), privacy: .public) (\(id, privacy: .public)) after \(timeUsed.milliseconds, privacy: .public) ms")
#endif
            let asyncDelay: UInt = delay > 0 ? delay : UInt(ASYNCDELAY)
            if asyncDelay > 0 {     // test LoadingView, sleep some seconds
                try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(asyncDelay))
            }
            return response
        } catch {       // rethrows
            let timeUsed = Date.now - sendTime
            logger.error("\(request.operation(), privacy: .public) failed after \(timeUsed.milliseconds, privacy: .public) ms\n\(error, privacy: .public)")
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
    func operation() -> String { "getTransactionById" }
    func args() -> Args { Args(transactionId: transactionId) }

    var transactionId: String

    struct Args: Encodable {
        var transactionId: String
    }
}
// MARK: -
/// The info returned from Wallet-core init
struct VersionInfo: Decodable {
    var hash: String?
    var version: String
    var exchange: String
    var merchant: String
    var bank: String
    var devMode: Bool
}
// MARK: -
///  A request to initialize Wallet-core
fileprivate struct InitRequest: WalletBackendFormattedRequest {
    func operation() -> String { "init" }
    func args() -> Args {
        return Args(persistentStoragePath: persistentStoragePath,
//                       cryptoWorkerType: "sync",
                                 logLevel: "info", // trace, info, warn, error, none
                         useNativeLogging: true)
    }

    struct Args: Encodable {
        var persistentStoragePath: String
//        var cryptoWorkerType: String
        var logLevel: String
        var useNativeLogging: Bool
    }

    var persistentStoragePath: String

    struct Response: Decodable {
        var versionInfo: VersionInfo
    }
}

extension WalletModel {
    /// initalize Wallet-Core. Will do networking
    func initWalletCoreT(sqlite3: Bool) async throws -> VersionInfo {
                    // T for any Thread
        let docPath = try docPath(sqlite3: sqlite3)
        let request = InitRequest(persistentStoragePath: docPath)
        let response = try await sendRequest(request, 0)    // no Delay
        return response.versionInfo
    }

    private func docPath (sqlite3: Bool) throws -> String {
        if let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let documentUrl = documentsUrl.appendingPathComponent(DATABASE, isDirectory: false)
                                          .appendingPathExtension(sqlite3 ? "sqlite3" : "json")
            let docPath = documentUrl.path
            logger.debug("\(docPath)")
            return docPath
        } else {    // should never happen
            logger.error("No documentDirectory")
            throw WalletBackendError.initializationError
        }
    }

    private func cachePath () throws -> String {
        let fileManager = FileManager.default
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheURL = cachesURL.appendingPathComponent("cache.json")
            let cachePath = cacheURL.path
            logger.debug("\(cachePath)")

            if !fileManager.fileExists(atPath: cachePath) {
                let contents = Data()       /// Initialize an empty `Data`.
                fileManager.createFile(atPath: cachePath, contents: contents)
                print("❗️ File \(cachePath) created")
            } else {
                print("❗️ File \(cachePath) already exists")
            }

            return cachePath
        } else {    // should never happen
            logger.error("No cachesDirectory")
            throw WalletBackendError.initializationError
        }
    }
}
// MARK: -
///  A request to initialize Wallet-core
fileprivate struct ResetRequest: WalletBackendFormattedRequest {
    func operation() -> String { "reset" }
    func args() -> Args { Args() }

    struct Args: Encodable {}                           // no arguments needed
    struct Response: Decodable {}
}

extension WalletModel {
    /// reset Wallet-Core
    func resetWalletCoreT() async throws {
        // T for any Thread
        let request = ResetRequest()
        _ = try await sendRequest(request, 0)
    }
}
