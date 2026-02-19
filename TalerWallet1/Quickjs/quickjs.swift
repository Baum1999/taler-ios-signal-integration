/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import os.log

import FTalerWalletcore

public protocol QuickjsMessageHandler: AnyObject {
    func handleMessage(message: String)
    func handleLog(message: String)
}
// MARK: -
func notification_callback(userdata: Optional<UnsafeMutableRawPointer>,
                           payload: Optional<UnsafePointer<Int8>>) {
    let quickjs = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    let string = String(cString: payload!)
    quickjs.internalOnNotify(payload: string)
}

func logging_callback(userdata: Optional<UnsafeMutableRawPointer>,
                          level: TALER_WALLET_LogLevel,
                            tag: Optional<UnsafePointer<Int8>>,
                        message: Optional<UnsafePointer<Int8>>) {
    let quickjs = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    let logger = quickjs.logger
    let swiftTag = String(cString: tag!)
    let swiftMessage = String(cString: message!)

    switch level {
        case TALER_WALLET_LOG_ERROR:
            logger.error("\(swiftTag, privacy: .public)  \(swiftMessage, privacy: .public)")
        case TALER_WALLET_LOG_WARN:
            logger.warning("\(swiftTag, privacy: .public)  \(swiftMessage, privacy: .public)")
        case TALER_WALLET_LOG_MESSAGE:
            logger.notice("\(swiftTag, privacy: .public)  \(swiftMessage, privacy: .public)")
        case TALER_WALLET_LOG_INFO:
            logger.info("\(swiftTag, privacy: .public)  \(swiftMessage, privacy: .public)")
        case TALER_WALLET_LOG_TRACE:
            logger.trace("\(swiftTag, privacy: .public)  \(swiftMessage, privacy: .public)")
        default: break
    }
    quickjs.internalOnLog(message: swiftMessage)
}
// MARK: -
public class Quickjs {      // acts as singleton, since only one instance ever exists
    var talerWalletInstance: OpaquePointer!
    public weak var messageHandler: QuickjsMessageHandler?
    var logger: Logger

    @Atomic(default: 0)                                                         // boilerPlate around NSLock…
    private var lastRequestID: Int32                                            // …to safeguard increments
    private var requests: [Int32: QuickDataTask] = [:]

    private lazy var urlSession: URLSession = {
        return URLSession(configuration: .ephemeral)    // we don't want the filesystem cache - keep it in RAM
    }()

    public init() {
        self.logger = Logger(subsystem: "net.taler.gnu", category: "QuickJS")
        self.talerWalletInstance = TALER_WALLET_create()
        TALER_WALLET_set_message_handler(talerWalletInstance,
                                         notification_callback,
                                         Unmanaged.passUnretained(self).toOpaque())
        TALER_WALLET_set_log_handler(talerWalletInstance,
                                     logging_callback,
                                     Unmanaged.passUnretained(self).toOpaque())
        let http_impl = TALER_pack_http_client_implementation(request_create, request_cancel,
                                                              Unmanaged.passUnretained(self).toOpaque())
        // http_impl got malloc'd, and could possibly be free'd when the app terminates
        TALER_set_http_client_implementation(talerWalletInstance, http_impl)
        // - but we never free anything on termination, thus we don't save http_impl here
        TALER_WALLET_run(talerWalletInstance)
    }

    func reqCreate(_ request: URLRequest,
                _ responseCb: JSHttpResponseCb?,
             _ responseCbCls: Optional<UnsafeMutableRawPointer>) -> Int32 {
        let requestID = $lastRequestID.atomicIncrement()                        // ensure requestID is unique
        let quickDataTask = QuickDataTask(urlSession: urlSession,
                                             request: request,
                                           requestID: requestID,
                                            requests: &requests,
                                          responseCb: responseCb,
                                       responseCbCls: responseCbCls)
        quickDataTask.run()
        requests[requestID] = quickDataTask
        return requestID
    }

    func reqCancel(_ requestID: Int32) -> Int32 {
        if let quickDataTask = requests[requestID] {
            if let dataTask = quickDataTask.dataTask {
                dataTask.cancel()
            }
        }
        requests[requestID] = nil
        return 0
    }

    deinit {
        // No need to call TALER_WALLET_destroy - memory gets purged anyway
    }

    func internalOnNotify(payload: String) {
        if let handler = messageHandler {
            handler.handleMessage(message: payload)
        }
    }

    public func internalOnLog(message: String) {
        if let handler = messageHandler {
            handler.handleLog(message: message)
        }
    }

//    public func notifyNative() {
//        __notifyNative(instance)
//    }

//    public func evalNodeCode(source: String) {
//        scheduleNodeThreadAsync {
//            __makeCallbackNative(self.instance, source.cString(using: .utf8))
//        }
//    }

    public func sendMessage(message: String) {
        TALER_WALLET_send_request(talerWalletInstance, message)
    }
}
