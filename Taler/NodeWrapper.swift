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

protocol IonoMessageHandler {
    func handleMessage(message: String)
}

func notification_callback(payload: Optional<UnsafePointer<Int8>>,
                           userdata: Optional<UnsafeMutableRawPointer>) {
    let native = Unmanaged<Iono>.fromOpaque(userdata!).takeUnretainedValue()
    let string = String(cString: payload!)
    native.internalOnNotify(payload: string)
}

class Iono {
    var instance: OpaquePointer!
    var work_queue: DispatchQueue
    var initialization_group: DispatchGroup
    var messageHandler: IonoMessageHandler?
    
    init() {
        work_queue = DispatchQueue(label: "NodeQueue", qos: .userInitiated)
        initialization_group = DispatchGroup()
        initialization_group.notify(queue: work_queue) {
            self.instance = __initNative()
            __setNotifyHandler(self.instance, notification_callback, Unmanaged.passUnretained(self).toOpaque())
        }
    }
    
    deinit {
        __destroyNative(instance)
    }
    
    private func scheduleNodeThreadAsync(block: @escaping () -> Void) {
        initialization_group.wait()
        work_queue.async(execute: block)
        notifyNative()
    }
    
    private func scheduleNodeThreadSync(block: @escaping () -> Void) {
        initialization_group.wait()
        work_queue.sync(execute: block)
        notifyNative()
    }
    
    func internalOnNotify(payload: String) {
        if let handler = messageHandler {
            handler.handleMessage(message: payload)
        }
    }
    
    func notifyNative() {
        initialization_group.wait()
        __notifyNative(instance)
    }
    
    func evalSimpleJs(source: String) -> String {
        var result: String?
        scheduleNodeThreadSync {
            let cResult = __evalJs(self.instance, source.cString(using: .utf8))
            if let cStr = cResult {
                result = String(cString: cStr)
                free(cResult)
            }
        }
        return result!
    }
    
    func evalNodeCode(source: String) {
        scheduleNodeThreadAsync {
            __makeCallbackNative(self.instance, source.cString(using: .utf8))
        }
    }
    
    func sendMessage(message: String) {
        let encoded = message.data(using: .utf8)!.base64EncodedString()
        let source = """
            if (global.__iono_onMessage) {
                const msg = (new Buffer('\(encoded)', 'base64')).toString('ascii');
                global.__iono_onMessage(msg);
            } else {
                console.log("WARN: no __iono_onMessage defined");
            }
        """
        evalNodeCode(source: source)
    }
    
    func waitStopped() {
        
    }
    
    func putModuleCode(modName: String, code: String) {
        __putModuleCodeNative(instance, modName.cString(using: .utf8),
                              code.cString(using: .utf8))
    }
}
