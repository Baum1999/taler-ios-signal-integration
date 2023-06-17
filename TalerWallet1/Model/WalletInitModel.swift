/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import SymLog

private let DATABASE = "talerwalletdb-v30"

class WalletInitModel: WalletModel {
    override init(_ symbol: Int = -1) {     // init with 0 to disable logging for this class
        super.init(symbol)
    }
}
// MARK: -
///  A request to initialize Wallet-core
fileprivate struct WalletBackendInitRequest: WalletBackendFormattedRequest {
    func operation() -> String { return "init" }
    func args() -> Args {
        return Args(persistentStoragePath: persistentStoragePath,
//                    cryptoWorkerType: "sync",
                    logLevel: "info")       //  "trace", "info", "warn", "error", "none"
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
extension WalletInitModel {
    /// initalize Wallet-Core. Will do networking
    func initWalletT()              // T for any Thread
      async throws -> VersionInfo? {
          let docPath = try docPath()
          let request = WalletBackendInitRequest(persistentStoragePath: docPath)
          symLog?.log("info: not main thread")
          let response = try await sendRequest(request, 0)    // no Delay
          return response.versionInfo
    }

    private func docPath () throws -> String {
        let documentUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if (documentUrls.count > 0) {
            var storageDir = documentUrls[0]
            storageDir.appendPathComponent(DATABASE, isDirectory: false)
            storageDir.appendPathExtension("json")
            return storageDir.path
        } else {    // should never happen
            symLog?.log("Yikes❗️ documentURLs empty")     // TODO: symLog.error
            throw WalletBackendError.initializationError
        }
    }
}

