/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
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
import iono

protocol WalletBackendRequest {
    associatedtype Args: Encodable
    
    func operation() -> String
    func args() -> Args
}

fileprivate struct WalletBackendRequestData<T: WalletBackendRequest>: Encodable {
    var operation: String
    var id: Int
    var args: T.Args
    
    init(request: T, id: Int) {
        operation = request.operation()
        self.id = id
        args = request.args()
    }
}

fileprivate struct WalletBackendInitRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var persistentStoragePath: String
    }
    typealias Args = RequestArgs
    private var requestArgs: RequestArgs
    
    init(persistentStoragePath: String) {
        requestArgs = RequestArgs(persistentStoragePath: persistentStoragePath)
    }
    
    func operation() -> String {
        return "init"
    }
    
    func args() -> Args {
        return requestArgs
    }
}

fileprivate struct WalletBackendGetTransactionsRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        
    }
    typealias Args = RequestArgs
    private var requestArgs: RequestArgs
    
    init() {
        requestArgs = RequestArgs()
    }
    
    func operation() -> String {
        return "getTransactions"
    }
    
    func args() -> Args {
        return requestArgs
    }
}

enum WalletBackendError: Error {
    case serializationError
}

class WalletBackend: IonoMessageHandler {
    private var iono: Iono
    private var requestsMade: Int
    
    init() {
        iono = Iono()
        requestsMade = 0
        
        iono.messageHandler = self
        
        let js_path = URL(fileURLWithPath: Bundle.main.path(forResource: "taler-wallet-embedded", ofType: "js")!)
        do {
            let js = try String(contentsOf: js_path, encoding: .utf8)
            iono.putModuleCode(modName: "@gnu-taler/taler-wallet-embedded", code: js)
            iono.evalNodeCode(source: "require('iono');")
            iono.evalNodeCode(source: "tw = require('@gnu-taler/taler-wallet-embedded');")
            iono.evalNodeCode(source: "tw.installNativeWalletListener();")
        } catch {

        }
        
        // Send the init message
        let documentUrls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if (documentUrls.count > 0) {
            var storageDir = documentUrls[0]
            storageDir.appendPathComponent("talerwalletdb-v30", isDirectory: false)
            storageDir.appendPathExtension("json")
            try! sendRequest(request: WalletBackendInitRequest(persistentStoragePath: storageDir.path))
        }
        //try! sendRequest(request: WalletBackendGetTransactionsRequest())
    }
    
    func handleMessage(message: String) {
        print("received message \(message)")
    }
    
    func sendRequest<T: WalletBackendRequest>(request: T) throws {
        let data = WalletBackendRequestData<T>(request: request, id: requestsMade)
        requestsMade += 1
        do {
            let encoded = try JSONEncoder().encode(data)
            guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
            iono.sendMessage(message: jsonString)
        } catch {
            throw WalletBackendError.serializationError
        }
    }
}
