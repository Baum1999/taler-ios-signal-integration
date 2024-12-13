/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
 */
import SwiftUI              // FOUNDATION has no AppStorage
import AnyCodable
import FTalerWalletcore
import SymLog
import os
import LocalConsole

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

    private let quickjs: Quickjs
    private var requestsMade: UInt          // counter for array of completion closures
    private var completions: [UInt : (Date, (UInt, Date, Data?, WalletBackendResponseError?) -> Void)] = [:]
    var delegate: WalletBackendDelegate?

    var versionInfo: VersionInfo?           // shown in SettingsView
    var developDelay: Bool?                 // if set in SettingsView will delay wallet-core after each action
    var isObserving: Int
    var isLogging: Bool
    let logger = Logger(subsystem: "net.taler.gnu", category: "WalletCore")

    private var expired: [String] = []      // save txID of expired items to not beep twice

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
        let error: WalletBackendResponseError?
        let payload: AnyCodable?
    }

    struct Payload: Decodable {
        let type: String
        let id: String?
        let reservePub: String?
        let event: [String: AnyCodable]?
    }

    deinit {
        logger.log("shutdown Quickjs")
    // TODO: send shutdown message to talerWalletInstance
//        quickjs.waitStopped()
    }

    init() throws {
        isObserving = 0
        isLogging = false
//        logger.trace("init Quickjs")
        requestsMade = 0
        queue = DispatchQueue(label: "net.taler.myQueue", attributes: .concurrent)
        semaphore = DispatchSemaphore(value: 1)
        quickjs = Quickjs()
        quickjs.messageHandler = self
        logger.log("Quickjs running")
    }
}
// MARK: -  completionHandler functions
extension WalletCore {
    private func handleError(_ decoded: ResponseOrNotification) throws {
        guard let requestId = decoded.id else {
            logger.error("didn't find requestId in error response")
            // TODO: show error alert
            throw WalletBackendError.deserializationError
        }
        guard let (timeSent, completion) = completions[requestId] else {
            logger.error("requestId \(requestId, privacy: .public) not in list")
            // TODO: show error alert
            throw WalletBackendError.deserializationError
        }
        completions[requestId] = nil
        if let walletError = decoded.error {            // wallet-core sent an error message
            do {
                let jsonData = try JSONEncoder().encode(walletError)
                let responseCode = walletError.errorResponse?.code ?? 0
                logger.error("wallet-core sent back error \(walletError.code, privacy: .public), \(responseCode, privacy: .public) for request \(requestId, privacy: .public)")
                symLog.log("id:\(requestId)  \(walletError)")
                completion(requestId, timeSent, jsonData, walletError)
            } catch {        // JSON encoding of response.result failed / should never happen
                symLog.log(decoded)
                logger.error("cannot encode wallet-core Error")
                completion(requestId, timeSent, nil, WalletCore.parseFailureError())
            }
        } else {             // JSON decoding of error message failed
            completion(requestId, timeSent, nil, WalletCore.parseFailureError())
        }
    }

    private func handleResponse(_ decoded: ResponseOrNotification) throws {
        guard let requestId = decoded.id else {
            logger.error("didn't find requestId in response")
            symLog.log(decoded)                 // TODO: .error
            throw WalletBackendError.deserializationError
        }
        guard let (timeSent, completion) = completions[requestId] else {
            logger.error("requestId \(requestId, privacy: .public) not in list")
            throw WalletBackendError.deserializationError
        }
        completions[requestId] = nil
        guard let result = decoded.result else {
            logger.error("requestId \(requestId, privacy: .public) got no result")
            throw WalletBackendError.deserializationError
        }
        do {
            let jsonData = try JSONEncoder().encode(result)
//            symLog.log("\"id\":\(requestId)  \(result)")
//            logger.info(result)   TODO: log result
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
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: userInfo)
    }
    private func postNotification(_ aName: NSNotification.Name,
                          object anObject: Any? = nil,
                                 userInfo: [AnyHashable: Any]? = nil) {
        Task { // runs on MainActor
            await postNotificationM(aName, object: anObject, userInfo: userInfo)
//            logger.info("Notification sent: \(aName.rawValue, privacy: .public)")
        }
    }

    private func handlePendingProcessed(_ payload: Payload) throws {
        guard let id = payload.id else {
            throw WalletBackendError.deserializationError
        }
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
        } else if id.hasPrefix("peer-pull-credit:") {
            // TODO: handle peer-pull-credit
//            symLog.log("\(pendingOp): \(id)")
        } else if id.hasPrefix("peer-push-debit:") {
            // TODO: handle peer-push-debit
//            symLog.log("\(pendingOp): \(id)")
        } else {
            // TODO: handle other pending-operation-processed
            logger.log("❗️ \(pendingOp, privacy: .public): \(id, privacy: .public)")        // this is a new pendingOp I haven't seen before
        }
    }
    @MainActor private func handleStateTransition(_ jsonData: Data) throws {
        do {
            let decoded = try JSONDecoder().decode(TransactionTransition.self, from: jsonData)
            if let errorInfo = decoded.errorInfo {
                // reload pending transaction list to add error badge
                postNotification(.TransactionError, userInfo: [NOTIFICATIONERROR: WalletBackendError.walletCoreError(errorInfo)])
            }
            guard decoded.newTxState != decoded.oldTxState else {
                logger.info("No State change: \(decoded.transactionId, privacy: .private(mask: .hash))")
                return
            }

            let components = decoded.transactionId.components(separatedBy: ":")
            if components.count >= 3 {  // txn:$txtype:$uid
                if let type = TransactionType(rawValue: components[1]) {
                    guard type != .refresh else { return }
                    let newMajor = decoded.newTxState.major
                    let newMinor = decoded.newTxState.minor
                    let oldMinor = decoded.oldTxState.minor
                    switch newMajor {
                        case .done:
                            logger.info("Done: \(decoded.transactionId, privacy: .private(mask: .hash))")
                            if type.isWithdrawal {
                                Controller.shared.playSound(2)  // play payment_received only for withdrawals
                            } else if !type.isIncoming {
                                if !(oldMinor == .autoRefund || oldMinor == .acceptRefund) {
                                    Controller.shared.playSound(1)  // play payment_sent for all outgoing tx
                                }
                            } else {    // incoming but not withdrawal
                                logger.info("incoming payment done - NO sound - \(type.rawValue)")
                            }
                            postNotification(.TransactionDone, userInfo: [TRANSACTIONTRANSITION: decoded])
                            return
                        case .aborting:
                            if let newMinor {
                                if newMinor == .refreshExpired {
                                    logger.warning("RefreshExpired: \(decoded.transactionId, privacy: .private(mask: .hash))")
                                    if let index = expired.firstIndex(of: components[2]) {
                                        expired.remove(at: index)               // don't beep twice
                                    } else {
                                        expired.append(components[2])
                                        Controller.shared.playSound(0)          // beep at first sight
                                    }
                                    postNotification(.TransactionExpired, userInfo: [TRANSACTIONTRANSITION: decoded])
                                    return
                                }
                            }
                            logger.warning("Unknown aborting: \(decoded.transactionId, privacy: .private(mask: .hash))")
                            postNotification(.TransactionStateTransition, userInfo: [TRANSACTIONTRANSITION: decoded])
                        case .expired:
                            logger.warning("Expired: \(decoded.transactionId, privacy: .private(mask: .hash))")
                            if let index = expired.firstIndex(of: components[2]) {
                                expired.remove(at: index)                       // don't beep twice
                            } else {
                                expired.append(components[2])
                                Controller.shared.playSound(0)                  // beep at first sight
                            }
                            postNotification(.TransactionExpired, userInfo: [TRANSACTIONTRANSITION: decoded])
                        case .pending:
                            if let newMinor {
                                if newMinor == .ready {
                                    logger.log("PendingReady: \(decoded.transactionId, privacy: .private(mask: .hash))")
                                    postNotification(.PendingReady, userInfo: [TRANSACTIONTRANSITION: decoded])
                                    return
                                } else if newMinor == .exchangeWaitReserve      // user did confirm on bank website
                                       || newMinor == .withdrawCoins {          // coin-withdrawal has started
//                                    logger.log("DismissSheet: \(decoded.transactionId, privacy: .private(mask: .hash))")
                                    postNotification(.DismissSheet, userInfo: [TRANSACTIONTRANSITION: decoded])
                                    return
                                } else if newMinor == .kyc {       // user did confirm on bank website, but KYC is needed
                                    logger.log("KYCrequired: \(decoded.transactionId, privacy: .private(mask: .hash))")
                                    postNotification(.KYCrequired, userInfo: [TRANSACTIONTRANSITION: decoded])
                                    return
                                }
                                logger.trace("Pending:\(newMinor.rawValue, privacy: .public) \(decoded.transactionId, privacy: .private(mask: .hash))")
                            } else {
                                logger.trace("Pending: \(decoded.transactionId, privacy: .private(mask: .hash))")
                            }
                            postNotification(.TransactionStateTransition, userInfo: [TRANSACTIONTRANSITION: decoded])
                        default:
                            if let newMinor {
                                logger.log("\(newMajor.rawValue, privacy: .public):\(newMinor.rawValue, privacy: .public) \(decoded.transactionId, privacy: .private(mask: .hash))")
                            } else {
                                logger.warning("\(newMajor.rawValue, privacy: .public): \(decoded.transactionId, privacy: .private(mask: .hash))")
                            }
                            postNotification(.TransactionStateTransition, userInfo: [TRANSACTIONTRANSITION: decoded])
                    } // switch
                } // type
            } // 3 components
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
        } catch let error {       // rethrows
            symLog.log(error)       // TODO: .error
        }
        throw WalletBackendError.walletCoreError(nil)       // TODO: error?
    }

    @MainActor private func handleNotification(_ anyCodable: AnyCodable?, _ message: String) throws {
        guard let anyPayload = anyCodable else {
            throw WalletBackendError.deserializationError
        }
        do {
            let jsonData = try JSONEncoder().encode(anyPayload)
            let payload = try JSONDecoder().decode(Payload.self, from: jsonData)

            switch payload.type {
                case Notification.Name.Idle.rawValue:
                    symLog.log(message)
                    break
                case Notification.Name.ExchangeStateTransition.rawValue:
                    symLog.log(message)
                    break
                case Notification.Name.TransactionStateTransition.rawValue:
                    symLog.log(message)
                    try handleStateTransition(jsonData)
                case Notification.Name.PendingOperationProcessed.rawValue:
                    try handlePendingProcessed(payload)
                case Notification.Name.BalanceChange.rawValue:
                    symLog.log(message)
                    postNotification(.BalanceChange)
                case Notification.Name.BankAccountChange.rawValue:
                    symLog.log(message)
                    postNotification(.BankAccountChange)
                case Notification.Name.ExchangeAdded.rawValue:
                    symLog.log(message)
                    postNotification(.ExchangeAdded)
                case Notification.Name.ExchangeDeleted.rawValue:
                    symLog.log(message)
                    postNotification(.ExchangeDeleted)
                case Notification.Name.ReserveNotYetFound.rawValue:
                    if let reservePub = payload.reservePub {
                        let userInfo = ["reservePub" : reservePub]
//                        postNotification(.ReserveNotYetFound, userInfo: userInfo)   // TODO: remind User to confirm withdrawal
                    } // else { throw WalletBackendError.deserializationError }   shouldn't happen, but if it does just ignore it

                case Notification.Name.ProposalAccepted.rawValue:               // "proposal-accepted":
                    symLog.log(message)
                    postNotification(.ProposalAccepted, userInfo: nil)
                case Notification.Name.ProposalDownloaded.rawValue:             // "proposal-downloaded":
                    symLog.log(message)
                    postNotification(.ProposalDownloaded, userInfo: nil)
                case Notification.Name.TaskObservabilityEvent.rawValue,
                     Notification.Name.RequestObservabilityEvent.rawValue:
                    if isObserving != 0 {
                        symLog.log(message)
                        let timestamp = TalerDater.dateString()
                        if let event = payload.event, let json = event.toJSON() {
                            let type = event["type"]?.value as? String
                            let eventID = event["id"]?.value as? String
                            observe(json: json,
                                    type: type,
                                    eventID: eventID,
                                    timestamp: timestamp)
                        }
                    }
                    // TODO: remove these once wallet-core doesn't send them anymore
//                case "refresh-started", "refresh-melted",
//                     "refresh-revealed", "refresh-unwarranted":
//                    break
                default:
print("\n❗️ WalletCore.swift:368 NEW Notification: ", message, "\n")        // this is a new notification I haven't seen before
                    break
            }
        } catch let error {
            symLog.log("Error \(error) parsing notification: \(message)")    // TODO: .error
            postNotification(.Error, userInfo: [NOTIFICATIONERROR: error])
        // TODO: if DevMode then should log into file for user
        }
    }

    @MainActor func handleLog(message: String) {
        if isLogging {
            let consoleManager = LCManager.shared
            consoleManager.print(message)
        }
    }

    @MainActor func observe(json: String, type: String?, eventID: String?, timestamp: String) {
        let consoleManager = LCManager.shared
        if let type {
            if let eventID {
                consoleManager.print("\(type)   \(eventID)")
            } else {
                consoleManager.print(type)
            }
        }
        consoleManager.print("   \(timestamp)")
        if isObserving < 0 {
            consoleManager.print(json)
        }
        consoleManager.print("-   -   -")
    }

    /// here not only responses, but also notifications from wallet-core will be received
    @MainActor func handleMessage(message: String) {
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
                    symLog.log("\"id\":\(decoded.id ?? 0)  \(message)")
                    try handleError(decoded)
                case "response":
                    symLog.log(message)
                    try handleResponse(decoded)
                case "notification":
//                    symLog.log(message)
                    try handleNotification(decoded.payload, message)
                case "tunnelHttp":          // TODO: Handle tunnelHttp
                    symLog.log("Can't handle tunnelHttp: \(message)")    // TODO: .error
                    throw WalletBackendError.deserializationError
                default:
                    symLog.log("Unknown response type: \(message)")    // TODO: .error
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
    
    private func encodeAndSend(_ request: WalletBackendRequest, completionHandler: @escaping (UInt, Date, Data?, WalletBackendResponseError?) -> Void) {
        // Encode the request and send it to the backend.
        queue.async {
            self.semaphore.wait()               // guard access to requestsMade
            let requestId = self.requestsMade
            let sendTime = Date.now
            do {
                let full = FullRequest(operation: request.operation, id: requestId, args: request.args)
//          symLog.log(full)
                let encoded = try JSONEncoder().encode(full)
                guard let jsonString = String(data: encoded, encoding: .utf8) else { throw WalletBackendError.serializationError }
                self.completions[requestId] = (sendTime, completionHandler)
                self.requestsMade += 1
                self.semaphore.signal()         // free requestsMade
                    let args = try JSONEncoder().encode(request.args)
                    if let jsonArgs = String(data: args, encoding: .utf8) {
                        self.logger.log("🔴\"id\":\(requestId, privacy: .public) \(request.operation, privacy: .public)\(jsonArgs, privacy: .auto)")
                    } else {    // should NEVER happen since the whole request was already successfully encoded and stringified
                        self.logger.log("🔴\"id\":\(requestId, privacy: .public) \(request.operation, privacy: .public) 🔴 Error: jsonArgs")
                    }
                self.quickjs.sendMessage(message: jsonString)
//              self.symLog.log(jsonString)
            } catch {       // call completion
                self.semaphore.signal()         // free requestsMade
                self.logger.error("\(error.localizedDescription)")
//              self.symLog.log(error)
                completionHandler(requestId, sendTime, nil, WalletCore.serializeRequestError());
            }
        }
    }
}
// MARK: -  async / await function
extension WalletCore {
    /// send async requests to wallet-core
    func sendFormattedRequest<T: WalletBackendFormattedRequest> (_ request: T) async throws -> (T.Response, UInt) {
        let reqData = WalletBackendRequest(operation: request.operation(),
                                           args: AnyEncodable(request.args()))
        return try await withCheckedThrowingContinuation { continuation in
            encodeAndSend(reqData) { requestId, timeSent, result, error in
                let timeUsed = Date.now - timeSent
                let millisecs = timeUsed.milliseconds
                if let error {
                    self.logger.error("Request \"id\":\(requestId, privacy: .public) failed after \(millisecs, privacy: .public) ms")
                } else {
                    self.logger.info("Request \"id\":\(requestId, privacy: .public) took \(millisecs, privacy: .public) ms")
                }
                var err: Error? = nil
                if let json = result, error == nil {
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
                        err = error     // this will be thrown in continuation.resume(throwing:), otherwise keep nil
                    }
                } else if let error {
                    // TODO: WALLET_CORE_REQUEST_CANCELLED
                    self.lastError = FullError(type: "error", operation: request.operation(), id: requestId, error: error)
                    err = WalletBackendError.walletCoreError(error)
                } else {        // both result and error are nil
                    self.lastError = nil
                }
                continuation.resume(throwing: err ?? TransactionDecodingError.invalidStringValue)
            }
        }
    }
}
