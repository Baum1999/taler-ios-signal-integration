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

import FTalerWalletcore

public protocol QuickjsMessageHandler: AnyObject {
    func handleMessage(message: String)
}

func notification_callback(userdata: Optional<UnsafeMutableRawPointer>,
                           payload: Optional<UnsafePointer<Int8>>) {
    let native = Unmanaged<Quickjs>.fromOpaque(userdata!).takeUnretainedValue()
    let string = String(cString: payload!)
    native.internalOnNotify(payload: string)
}

public class Quickjs {
    var talerWalletInstance: OpaquePointer!
    public weak var messageHandler: QuickjsMessageHandler?

    public init() {
        self.talerWalletInstance = TALER_WALLET_create()
        TALER_WALLET_set_message_handler(talerWalletInstance,
                                         notification_callback,
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
