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
import SwiftUI              // FOUNDATION has no AppStorage
import AnyCodable
import FTalerWalletcore
import SymLog

/// Delegate for the wallet backend.
protocol WalletBackendDelegate {
    /// Called when the backend interface receives a message it does not know how to handle.
    func walletBackendReceivedUnknownMessage(_ walletCore: WalletCore, message: String)
}

/// An interface to the wallet backend.
class WalletCore: QuickjsMessageHandler {
    private let symLog = SymLogC()

    private var quickjs: Quickjs
    private var requestsMade: UInt          // counter for array of completion closures
    private var completions: [UInt : (UInt, Data?, WalletBackendResponseError?) -> Void] = [:]
    var delegate: WalletBackendDelegate?

    var versionInfo: VersionInfo?           // shown in SettingsView
    var developDelay: Bool?                 // if set in SettingsView will delay wallet-core after each action

    private struct FullRequest: Encodable {
        let operation: String
        let id: UInt
        let args: AnyEncodable
    }
    
    private struct FullResponse: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let result: AnyCodable
    }
    
    struct FullError: Decodable {
        let type: String
        let operation: String
        let id: UInt
        let error: WalletBackendResponseError
    }

    var lastError: FullError?

    deinit {
        symLog.log()
    // TODO: send shutdown message to talerWalletInstance
//        quickjs.waitStopped()
    }

    init() throws {
        requestsMade = 0
        quickjs = Quickjs()
        quickjs.messageHandler = self
    }
}
// MARK: -  completionHandler functions
extension WalletCore {

    private func handleResponse(dict responseDict: [String : Any], data messageData: Data, isError: Bool = false) throws {
        guard let id = responseDict["id"] as? UInt else { throw WalletBackendError.deserializationError }
        guard let completion = completions[id] else { throw WalletBackendError.deserializationError }
        completions[id] = nil
        if isError {
            do {
                let decoded = try JSONDecoder().decode(FullError.self, from: messageData)
                symLog.log(decoded)
                completion(id, nil, decoded.error)
            } catch {
                symLog.log(responseDict)        // TODO: error
                completion(id, nil, WalletCore.parseFailureError())
            }
        } else {
            do {    // pass response.result
                let decoded = try JSONDecoder().decode(FullResponse.self, from: messageData)
                symLog.log(decoded)
                let jsonData = try JSONEncoder().encode(decoded.result)
                completion(id, jsonData, nil)
            } catch {
                symLog.log(responseDict)        // TODO: error
                completion(id, nil, WalletCore.parseResponseError())
            }
        }
    }

    private func handleNotification(dict responseDict: [String : Any]) throws {
        do {
            guard let payload = (responseDict["payload"] as? [String : Any]) else { throw WalletBackendError.deserializationError }
            guard let type = (payload["type"] as? String) else { throw WalletBackendError.deserializationError }
            switch type {
                case "pending-operation-processed":
                    guard let id = (payload["id"] as? String) else { throw WalletBackendError.deserializationError }
                    if id.hasPrefix("exchange-update:") {
                        // TODO: handle exchange-update
                    } else {
                        symLog.log(id)
                        // TODO: handle other pending-operation-processed
                    }
                case "coin-withdrawn", "withdraw-group-finished", "pay-operation-success":
                    symLog.log(payload)
                    Task {
                        do {
                            try await Controller.shared.balancesModel.fetchBalances()
                        } catch {
                            // TODO: show error
                            symLog.log(error.localizedDescription)
                        }
                    }
                    break
                case "proposal-accepted":
                    symLog.log(payload)
                    break
                case "proposal-downloaded":
                    symLog.log(payload)
                    break
                case "waiting-for-retry":
                    // Bla Bla Bla
                    break
                case "exchange-added":
                    symLog.log(payload)
                    break
                case "refresh-started":
                    symLog.log(payload)
                    break
                case "refresh-melted":
                    symLog.log(payload)
                    break
                case "refresh-revealed":
                    symLog.log(payload)
                    break
                case "reserve-registered-with-bank":
                    symLog.log(payload)
                    break
                default:
                    symLog.log(payload)
                    break
            }
        } catch let error {
            symLog.log("Error \(error) parsing notification: \(responseDict)")    // TODO: .error
        // TODO: if DevMode then should log into file for user
        }
    }

    /// here not only responses, but also notifications from wallet-core will be received
    func handleMessage(message: String) {
        do {
            var asyncDelay = 0
            if let delay = developDelay {
                if delay {
                    asyncDelay = 2
                }
            }
            if asyncDelay > 0 {
                symLog.log(message)
                symLog.log("...going to sleep for \(asyncDelay) seconds...")
                sleep(UInt32(asyncDelay))
                symLog.log("waking up again after \(asyncDelay) seconds, will deliver message")
            }
            guard let messageData = message.data(using: .utf8) else { throw WalletBackendError.deserializationError }
            let jsonDict = try JSONSerialization.jsonObject(with: messageData, options: .allowFragments) as? [String : Any]
            guard let responseDict = jsonDict else { throw WalletBackendError.deserializationError }
            guard let responseType = (responseDict["type"] as? String) else { throw WalletBackendError.deserializationError }
            switch responseType {
                case "error":
                    try handleResponse(dict: responseDict, data: messageData, isError: true)
                case "response":
                    try handleResponse(dict: responseDict, data: messageData)
                case "notification":
                    try handleNotification(dict: responseDict)
                case "tunnelHttp":          // TODO: Handle tunnelHttp
                    break
                default:
                    symLog.log("Unknown response type: \(responseDict)")    // TODO: .error
                    throw WalletBackendError.deserializationError
            }
        } catch {
            delegate?.walletBackendReceivedUnknownMessage(self, message: message)
        }
    }
    
    private func sendRequest(request: WalletBackendRequest, completionHandler: @escaping (UInt, Data?, WalletBackendResponseError?) -> Void) {
        // Encode the request and send it to the backend.
        let id = requestsMade
        do {
            let full = FullRequest(operation: request.operation, id: id, args: request.args)
//            symLog.log(full)
            let encoded = try JSONEncoder().encode(full)
            guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
            completions[id] = completionHandler
            requestsMade += 1
            symLog.log(jsonString)
            quickjs.sendMessage(message: jsonString)
        } catch {
            completionHandler(id, nil, WalletCore.serializeRequestError());
        }
    }

    /// call this to send requests to wallet-core
    func sendFormattedRequest<T: WalletBackendFormattedRequest>
            (request: T, completionHandler: @escaping (T.Response?, WalletBackendResponseError?) -> Void)
    {
        let reqData = WalletBackendRequest(operation: request.operation(),
                                                args: AnyEncodable(request.args()))
        sendRequest(request: reqData) { (id: UInt, result: Data?, err: WalletBackendResponseError?) in
            guard let json = result else { completionHandler(nil, err); return }
            do {
                let decoded = try JSONDecoder().decode(T.Response.self, from: json)
                completionHandler(decoded, err)
            } catch {
                completionHandler(nil, WalletCore.parseResponseError())
            }
        }
    }
}
// MARK: -  async / await function
extension WalletCore {
    /// send async requests to wallet-core
    func sendFormattedRequest<T: WalletBackendFormattedRequest> (request: T) async throws -> (T.Response, UInt) {
        let reqData = WalletBackendRequest(operation: request.operation(),
                                           args: AnyEncodable(request.args()))
        return try await withCheckedThrowingContinuation { continuation in
            sendRequest(request: reqData) { id, result, error in
                if let json = result {
                    do {
                        let decoded = try JSONDecoder().decode(T.Response.self, from: json)
                        continuation.resume(returning: (decoded, id))
                    } catch {
                        if let jsonString = String(data: json, encoding: .utf8) {
                            self.symLog.log(jsonString)       // TODO: .error
                        } else {
                            self.symLog.log(json)       // TODO: .error
                        }
                        continuation.resume(throwing: error)
                    }
                } else {
                    if let error = error {
                        self.lastError = FullError(type: "error", operation: request.operation(), id: id, error: error)
                    } else {
                        self.lastError = nil
                    }
                    continuation.resume(throwing: WalletBackendError.walletCoreError)
                }
            }
        }
    }
}
