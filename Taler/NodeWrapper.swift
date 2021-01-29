//
//  NodeWrapper.swift
//  Taler
//
//  Created by Jonathan Buchanan on 1/14/21.
//  Copyright © 2021 Taler. All rights reserved.
//

import Foundation

class Iono {
    var __instance: OpaquePointer
    var messageHandler: ((String) -> ())?
    
    init() {
        __instance = __new_instance()
    }
    
    deinit {
        __free_instance(__instance)
    }
    
    func notifyNative() {
        
    }
    
    func evalJS(source: String) -> String {
        var result_cstr: UnsafeMutablePointer<Int8> = __eval_js(source.cString(using: .utf8), __instance)
        var result = String(cString: result_cstr)
        free(result_cstr)
        return result
    }
    
    func evalNodeCode(source: String) {
        __make_callback(source.cString(using: .utf8), __instance)
    }
    
    func sendMessage(message: String) {
        
    }
    
    func waitUntilStopped() {
        
    }
    
    func putModuleCode(moduleName: String, code: String) {
        __put_module_code(moduleName.cString(using: .utf8), code.cString(using: .utf8), __instance)
    }
}
