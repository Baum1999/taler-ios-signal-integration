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

enum WalletBackendResponseError: Error {
    case malformedResponse
}

protocol WalletBackendRequest {
    associatedtype Args: Encodable
    associatedtype Response: Decodable
    
    func operation() -> String
    func args() -> Args
    func success(result: Response)
    func error(_ err: WalletBackendResponseError)
}

fileprivate struct WalletBackendRequestData<T: WalletBackendRequest>: Encodable {
    var operation: String
    var id: UInt
    var args: T.Args
    
    init(request: T, id: UInt) {
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
    struct Response: Codable {
        struct SupportedProtocolVersions: Codable {
            var exchange: String
            var merchant: String
        }
        var supportedProtocolVersions: SupportedProtocolVersions
        enum CodingKeys: String, CodingKey {
            case supportedProtocolVersions = "supported_protocol_versions"
        }
    }
    private var requestArgs: RequestArgs
    private let success: () -> Void
    
    init(persistentStoragePath: String, onSuccess: @escaping () -> Void) {
        requestArgs = RequestArgs(persistentStoragePath: persistentStoragePath)
        self.success = onSuccess
    }
    
    func operation() -> String {
        return "init"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        self.success()
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

fileprivate struct WalletBackendGetTransactionsRequest: WalletBackendRequest {
    struct RequestArgs: Encodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = String
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
    
    func success(result: Response) {
        
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

struct WalletBackendGetBalancesRequest: WalletBackendRequest {
    struct Balance: Decodable {
        var available: Amount
        var pendingIncoming: Amount
        var pendingOutgoing: Amount
        var requiresUserInput: Bool
    }
    struct BalancesResponse: Decodable {
        var balances: [Balance]
    }
    struct RequestArgs: Encodable {
        
    }
    typealias Args = RequestArgs
    typealias Response = BalancesResponse
    private var requestArgs: RequestArgs
    private let success: ([Balance]) -> Void
    private let failure: () -> Void
    
    init(onSuccess: @escaping ([Balance]) -> Void, onFailure: @escaping () -> Void) {
        self.requestArgs = RequestArgs()
        self.success = onSuccess
        self.failure = onFailure
    }
    
    func operation() -> String {
        return "getBalances"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        print("balances???")
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

struct WalletBackendWithdrawTestBalance: WalletBackendRequest {
    struct RequestArgs: Encodable {
        var amount: String
        var bankBaseUrl: String
        var exchangeBaseUrl: String
    }
    typealias Args = RequestArgs
    typealias Response = String
    private var requestArgs: RequestArgs
    
    init(amount: String, bankBaseUrl: String, exchangeBaseUrl: String) {
        requestArgs = RequestArgs(amount: amount, bankBaseUrl: bankBaseUrl, exchangeBaseUrl: exchangeBaseUrl)
    }
    
    func operation() -> String {
        return "withdrawTestBalance"
    }
    
    func args() -> Args {
        return requestArgs
    }
    
    func success(result: Response) {
        
    }
    
    func error(_ err: WalletBackendResponseError) {
        
    }
}

enum WalletBackendError: Error {
    case serializationError
    case deserializationError
}

class WalletBackend: IonoMessageHandler {
    private var iono: Iono
    private var requestsMade: UInt
    private var backendReady: Bool
    private var backendReadyCondition: NSCondition
    private struct RequestDetail {
        let decodeSuccess: (Data) -> Void
        //let handleError: (Data) -> Void
    }
    private var requests: [UInt : RequestDetail] = [:]
    
    init() {
        iono = Iono()
        requestsMade = 0
        self.backendReady = false
        self.backendReadyCondition = NSCondition()
        
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
            try! sendRequest(request: WalletBackendInitRequest(persistentStoragePath: storageDir.path, onSuccess: {
                self.backendReady = true
                self.backendReadyCondition.broadcast()
            }))
        }
        
        waitUntilReady()
        //try! sendRequest(request: WalletBackendWithdrawTestBalance(amount: "TESTKUDOS:10", bankBaseUrl: "https://bank.test.taler.net/", exchangeBaseUrl: "https://exchange.test.taler.net/"))
        try! sendRequest(request: WalletBackendGetBalancesRequest(onSuccess: { ([WalletBackendGetBalancesRequest.Balance]) -> Void in
            
        }, onFailure: { () -> Void in
            
        }))
    }
    
    func waitUntilReady() {
        backendReadyCondition.lock()
        while (!self.backendReady) {
            backendReadyCondition.wait()
        }
        backendReadyCondition.unlock()
    }
    
    func handleMessage(message: String) {
        print(message)
        do {
            guard let messageData = message.data(using: .utf8) else { throw WalletBackendError.deserializationError }
            let data = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [String : Any]
            if let responseData = data {
                let type = (responseData["type"] as? String) ?? ""
                if type == "response" {
                    guard let id = responseData["id"] as? UInt else { /* TODO: error. */ return }
                    guard let request = requests[id] else { /* TODO: error. */ return }
                    request.decodeSuccess(messageData)
                    requests[id] = nil
                } else if type == "tunnelHttp" {
                    
                } else if type == "notification" {
                    
                } else if type == "error" {
                    guard let id = responseData["id"] as? UInt else { /* TODO: error. */ return }
                    guard let request = requests[id] else { /* TODO: error. */ return }
                    //request.handleError(messageData)
                    requests[id] = nil
                } else {
                    /* TODO: unknown response type. */
                }
            }
        } catch {
            
        }
    }
    
    private struct FullResponse<T: WalletBackendRequest>: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let result: T.Response
    }
    
    /*private struct FullError: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let error: WalletErrorDetail
    }*/
    
    func sendRequest<T: WalletBackendRequest>(request: T) throws {
        let data = WalletBackendRequestData<T>(request: request, id: requestsMade)
        requestsMade += 1
        let decodeSuccess = { (data: Data) -> Void in
            do {
                let decoded = try JSONDecoder().decode(FullResponse<T>.self, from: data)
                request.success(result: decoded.result)
            } catch {
                
            }
        }
        
        /* Encode the request and send it to the backend. */
        do {
            let encoded = try JSONEncoder().encode(data)
            guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
            let detail = RequestDetail(decodeSuccess: decodeSuccess)
            requests[data.id] = detail
            iono.sendMessage(message: jsonString)
        } catch {
            throw WalletBackendError.serializationError
        }
    }
}
