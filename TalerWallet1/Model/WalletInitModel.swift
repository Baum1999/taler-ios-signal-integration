/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import Foundation
import SymLog

let DATABASE = "talerwalletdb-v30"

class WalletInitModel: WalletModel {

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

    struct Response: Decodable {        // versioninfo
        var versionInfo: VersionInfo
        enum CodingKeys: String, CodingKey {
            case versionInfo = "versionInfo"
        }
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
    func initWallet() async throws -> VersionInfo? {
        do {
            let docPath = try docPath()
            let request = WalletBackendInitRequest(persistentStoragePath: docPath)
            symLog?.log("info: not main thread")
            let response = try await sendRequest(request, 0)    // no Delay
            return response.versionInfo
        } catch {
            symLog?.log("error: \(error)")
            throw error
        }
    }

    private func docPath () throws -> String {
        let documentUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if (documentUrls.count > 0) {
            var storageDir = documentUrls[0]
            storageDir.appendPathComponent(DATABASE, isDirectory: false)
            storageDir.appendPathExtension("json")
            return storageDir.path
        } else {    // should never happen
            symLog?.log("Yikes! documentURLs empty")     // TODO: symLog.error
            throw WalletBackendError.initializationError
        }
    }
}

