/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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

// MARK: -
/// An interface to the wallet backend.
class WalletCore: QuickjsMessageHandler {
    public static let shared = try! WalletCore()          // will (and should) crash on failure
    private let symLog = SymLogC()

    private var queue: DispatchQueue
    private var semaphore: DispatchSemaphore

    private var quickjs: Quickjs
    private var requestsMade: UInt          // counter for array of completion closures
    private var completions: [UInt : (Date, (UInt, Date, Data?, WalletBackendResponseError?) -> Void)] = [:]
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

    struct ResponseOrNotification: Decodable {
        let type: String
        let operation: String?
        let id: UInt?
        let result: AnyCodable?
        let error: AnyCodable?  // should be WalletBackendResponseError?
        let payload: AnyCodable?
    }

    struct Payload: Decodable {
        let type: String
        let id: String?
        let reservePub: String?
    }

    deinit {
        symLog.log()
    // TODO: send shutdown message to talerWalletInstance
//        quickjs.waitStopped()
    }

    init() throws {
        symLog.log("alloc.init wallet-core")
        requestsMade = 0
        queue = DispatchQueue(label: "net.taler.myQueue", attributes: .concurrent)
        semaphore = DispatchSemaphore(value: 1)
        quickjs = Quickjs()
        quickjs.messageHandler = self
        symLog.log("wallet-core done")
    }
}
// MARK: -  completionHandler functions
extension WalletCore {
    private func handleError(_ decoded: ResponseOrNotification) throws {
        guard let requestId = decoded.id else {
            symLog.log(decoded)                 // TODO: .error
            throw WalletBackendError.deserializationError
        }
        guard let (timeSent, completion) = completions[requestId] else {
            symLog.log("requestId \(requestId) not in list")       // TODO: .error
            throw WalletBackendError.deserializationError
        }
        completions[requestId] = nil
        if let walletError = decoded.error {            // wallet-core sent an error message
            do {
                let jsonData = try JSONEncoder().encode(walletError)
            } catch {        // JSON encoding of response.result failed / should never happen
                symLog.log(walletError)                 // TODO: .error
                completion(requestId, timeSent, nil, WalletCore.parseFailureError())
            }

            // TODO: decode jsonData to WalletBackendResponseError - or HTTPError
//            completion(requestId, timeSent, nil, walletError)
            completion(requestId, timeSent, nil, WalletCore.parseFailureError())
        } else {                                        // JSON decoding of error message failed
            completion(requestId, timeSent, nil, WalletCore.parseFailureError())
        }
    }
    private func handleResponse(_ decoded: ResponseOrNotification) throws {
        guard let requestId = decoded.id else {
            symLog.log(decoded)                 // TODO: .error
            throw WalletBackendError.deserializationError
        }
        guard let (timeSent, completion) = completions[requestId] else {
            symLog.log("requestId \(requestId) not in list")       // TODO: .error
            throw WalletBackendError.deserializationError
        }
        completions[requestId] = nil
        guard let result = decoded.result else {
            symLog.log("requestId \(requestId) got no result")       // TODO: .error
            throw WalletBackendError.deserializationError
        }
        do {
            let jsonData = try JSONEncoder().encode(result)
            symLog.log(result)                 // TODO: .info
            completion(requestId, timeSent, jsonData, nil)
        } catch {        // JSON encoding of response.result failed / should never happen
            symLog.log(result)                 // TODO: .error
            completion(requestId, timeSent, nil, WalletCore.parseResponseError())
        }
    }

    @MainActor
    private func postNotificationM(_ aName: NSNotification.Name,
                           object anObject: Any? = nil,
                                  userInfo: [AnyHashable: Any]? = nil) async {
        symLog.log(aName.rawValue)
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: userInfo)
    }
    private func postNotification(_ aName: NSNotification.Name,
                          object anObject: Any? = nil,
                                 userInfo: [AnyHashable: Any]? = nil) {
        Task {
            await postNotificationM(aName, object: anObject, userInfo: userInfo)
        }
        if let userInfo { symLog.log(userInfo) } else { symLog.log(aName) }
    }

    private func handlePendingProcessed(_ payload: Payload) throws {
        guard let id = payload.id else { throw WalletBackendError.deserializationError }
        let pendingOp = Notification.Name.PendingOperationProcessed.rawValue
        if id.hasPrefix("exchange-update:") {
            // Bla Bla Bla
        } else if id.hasPrefix("refresh:") {
            // Bla Bla Bla
        } else if id.hasPrefix("purchase:") {
            // TODO: handle purchase
//            symLog.log("\(pendingOp): \(id)")
        } else if id.hasPrefix("withdraw:") {
            // TODO: handle withdraw
//            symLog.log("\(pendingOp): \(id)")
        } else {
            // TODO: handle other pending-operation-processed
print("\n❗️ \(pendingOp): \(id)\n")        // this is a new pendingOp I haven't seen before
            print("\n")
        }
    }
    private func handleStateTransition(_ jsonData: Data) throws {
        do {
            let decoded = try JSONDecoder().decode(TransactionTransition.self, from: jsonData)
            postNotification(.TransactionStateTransition,
                             userInfo: [TRANSACTIONTRANSITION: decoded])
        } catch {       // rethrows
            symLog.log(jsonData)       // TODO: .error
            throw WalletBackendError.deserializationError
        }
    }

    private func handleNotification(_ anyCodable: AnyCodable?) throws {
        guard let anyPayload = anyCodable else { throw WalletBackendError.deserializationError }
        do {
            let jsonData = try JSONEncoder().encode(anyPayload)
            let payload = try JSONDecoder().decode(Payload.self, from: jsonData)

            switch payload.type {
                case Notification.Name.TransactionStateTransition.rawValue:
                    try handleStateTransition(jsonData)
                case Notification.Name.PendingOperationProcessed.rawValue:
                    try handlePendingProcessed(payload)
                case Notification.Name.ExchangeAdded.rawValue:
                    postNotification(.ExchangeAdded)
                case Notification.Name.ReserveNotYetFound.rawValue:
                    if let reservePub = payload.reservePub {
                        let userInfo = ["reservePub" : reservePub]
//                        postNotification(.ReserveNotYetFound, userInfo: userInfo)   // TODO: remind User to confirm withdrawal
                    } // else { throw WalletBackendError.deserializationError }   shouldn't happen, but if it does just ignore it

                case Notification.Name.ProposalAccepted.rawValue:               // "proposal-accepted":
                    symLog.log(anyPayload)
                    postNotification(.ProposalAccepted, userInfo: nil)
                case Notification.Name.ProposalDownloaded.rawValue:             // "proposal-downloaded":
                    symLog.log(anyPayload)
                    postNotification(.ProposalDownloaded, userInfo: nil)

                case "reserve-registered-with-bank":
                    symLog.log(anyPayload)

                // TODO: remove these once wallet-core doesn't send them anymore
                case "withdraw-group-finished",
                     "pay-operation-success",
                     "withdrawal-group-bank-confirmed",          // replaced by transaction-state-transition
                     "withdrawal-group-reserve-ready",
                     "coin-withdrawn",                           // totally useless since wallet-core handles coins in bulk
                     "waiting-for-retry",                        // Bla Bla Bla
                     "refresh-started", "refresh-melted",
                     "refresh-revealed", "refresh-unwarranted":
                    break
                default:
print("\n❗️ ", anyPayload, "\n")        // this is a new notification I haven't seen before
                    break
            }
        } catch let error {
            symLog.log("Error \(error) parsing notification: \(anyPayload)")    // TODO: .error
        // TODO: if DevMode then should log into file for user
        }
    }

    /// here not only responses, but also notifications from wallet-core will be received
    func handleMessage(message: String) {
        do {
            var asyncDelay = 0
            if let delay: Bool = developDelay {   // Settings: 2 seconds delay
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
            guard let messageData = message.data(using: .utf8) else {
                throw WalletBackendError.deserializationError
            }
            let decoded = try JSONDecoder().decode(ResponseOrNotification.self, from: messageData)
            switch decoded.type {
                case "error":
                    symLog.log(decoded)                 // TODO: .error
                    try handleError(decoded)
                case "response":
                    try handleResponse(decoded)
                case "notification":
                    try handleNotification(decoded.payload)
                case "tunnelHttp":          // TODO: Handle tunnelHttp
                    symLog.log("Can't handle tunnelHttp: \(decoded)")    // TODO: .error
                    throw WalletBackendError.deserializationError
                default:
                    symLog.log("Unknown response type: \(decoded)")    // TODO: .error
                    throw WalletBackendError.deserializationError
            }
        } catch DecodingError.dataCorrupted(let context) {
            print(context)
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch DecodingError.valueNotFound(let value, let context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch DecodingError.typeMismatch(let type, let context) {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch { // TODO: ?
            delegate?.walletBackendReceivedUnknownMessage(self, message: message)
        }
    }
    
    private func sendRequest(request: WalletBackendRequest, completionHandler: @escaping (UInt, Date, Data?, WalletBackendResponseError?) -> Void) {
        // Encode the request and send it to the backend.
        queue.async {
            self.semaphore.wait()               // guard access to requestsMade
            let requestId = self.requestsMade
            let now = Date.now
            do {
                let full = FullRequest(operation: request.operation, id: requestId, args: request.args)
                //            symLog.log(full)
                let encoded = try JSONEncoder().encode(full)
                guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
                self.completions[requestId] = (now, completionHandler)
                self.requestsMade += 1
                self.semaphore.signal()         // free requestsMade
                self.symLog.log(jsonString)
                self.quickjs.sendMessage(message: jsonString)
            } catch {       // call completion
                self.semaphore.signal()
                completionHandler(requestId, now, nil, WalletCore.serializeRequestError());
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
            sendRequest(request: reqData) { requestId, timeSent, result, error in
                let timeUsed = Date.now - timeSent
                let millisecs = timeUsed.milliseconds
print("Request \(requestId) took \(millisecs) ms")
                var err: Error? = nil
                if let json = result {
                    do {
                        let decoded = try JSONDecoder().decode(T.Response.self, from: json)
                        continuation.resume(returning: (decoded, requestId))
                        return
                    } catch DecodingError.dataCorrupted(let context) {
                        print(context)
                    } catch DecodingError.keyNotFound(let key, let context) {
                        print("Key '\(key)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch DecodingError.valueNotFound(let value, let context) {
                        print("Value '\(value)' not found:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch DecodingError.typeMismatch(let type, let context) {
                        print("Type '\(type)' mismatch:", context.debugDescription)
                        print("codingPath:", context.codingPath)
                    } catch {       // rethrows
                        if let jsonString = String(data: json, encoding: .utf8) {
                            self.symLog.log(jsonString)       // TODO: .error
                        } else {
                            self.symLog.log(json)       // TODO: .error
                        }
                        err = error     // this will be thrown
                    }
                } else {
                    if let error = error {
                        self.lastError = FullError(type: "error", operation: request.operation(), id: requestId, error: error)
                    } else {
                        self.lastError = nil
                    }
                    err = WalletBackendError.walletCoreError
                }
                continuation.resume(throwing: err ?? TransactionDecodingError.invalidStringValue)
            }
        }
    }
}
