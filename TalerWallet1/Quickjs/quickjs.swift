/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import os.log

import FTalerWalletcore

public protocol QuickjsMessageHandler: AnyObject {
    func handleMessage(message: String)
}
// MARK: -
func notification_callback(userdata: Optional<UnsafeMutableRawPointer>,
                           payload: Optional<UnsafePointer<Int8>>) {
    let native = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    let string = String(cString: payload!)
    native.internalOnNotify(payload: string)
}

func logging_callback(userdata: Optional<UnsafeMutableRawPointer>,
                          level: TALER_WALLET_LogLevel,
                            tag: Optional<UnsafePointer<Int8>>,
                        message: Optional<UnsafePointer<Int8>>) {
    let native = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    let logger = native.logger
    let theTag = String(cString: tag!)
    let theMessage = String(cString: message!)

    switch level {
        case TALER_WALLET_LOG_ERROR:
            logger.error("\(theTag, privacy: .public)  \(theMessage, privacy: .public)")
        case TALER_WALLET_LOG_WARN:
            logger.warning("\(theTag, privacy: .public)  \(theMessage, privacy: .public)")
        case TALER_WALLET_LOG_MESSAGE:
            logger.notice("\(theTag, privacy: .public)  \(theMessage, privacy: .public)")
        case TALER_WALLET_LOG_INFO:
            logger.info("\(theTag, privacy: .public)  \(theMessage, privacy: .public)")
        case TALER_WALLET_LOG_TRACE:
            logger.trace("\(theTag, privacy: .public)  \(theMessage, privacy: .public)")
        default: break
    }
}
// MARK: -
public class Quickjs {
    var talerWalletInstance: OpaquePointer!
    public weak var messageHandler: QuickjsMessageHandler?
    var logger: Logger

    public init() {
        self.logger = Logger(subsystem: "net.taler.gnu", category: "QuickJS")
        self.talerWalletInstance = TALER_WALLET_create()
        TALER_WALLET_set_message_handler(talerWalletInstance,
                                         notification_callback,
                                         Unmanaged.passUnretained(self).toOpaque())
        TALER_WALLET_set_log_handler(talerWalletInstance,
                                     logging_callback,
                                     Unmanaged.passUnretained(self).toOpaque())
        TALER_WALLET_run(talerWalletInstance);
    }

    deinit {
        // FIXME: TALER_WALLET_destroy
//        TALER_WALLET_destroy(talerWalletInstance)
    }


    public func internalOnNotify(payload: String) {
        if let handler = messageHandler {
            handler.handleMessage(message: payload)
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

    /// Note: This *must* be called before releasing the object, or else the thread will keep going.
//    public func waitStopped() {
//        scheduleNodeThreadSync {
//            self.stopped = true
//        }
//        thread.cancel()
//    }

//    public func putModuleCode(modName: String, code: String) {
//        __putModuleCodeNative(self.instance, modName.cString(using: .utf8),
//                              code.cString(using: .utf8))
//    }
}
