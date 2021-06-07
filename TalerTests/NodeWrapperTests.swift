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

import XCTest
@testable import Taler

class MessageHandler: IonoMessageHandler {
    var lastMessage: String?
    var messageSemaphore: DispatchSemaphore
    
    init() {
        messageSemaphore = DispatchSemaphore(value: 0)
    }
    
    func handleMessage(message: String) {
        lastMessage = message
        messageSemaphore.signal()
    }
}

class NodeWrapperTests: XCTestCase {
    var iono: Iono!
    var handler: MessageHandler!
    
    override func setUpWithError() throws {
        iono = Iono()
        handler = MessageHandler()
        
        iono.messageHandler = handler
    }

    override func tearDownWithError() throws {
        
    }

    func testEvalJS() throws {
        XCTAssert("2" == iono.evalSimpleJs(source: "1 + 1"))
        XCTAssert("36" == iono.evalSimpleJs(source: "6 * 6"))
        XCTAssert("42" == iono.evalSimpleJs(source: "(()=>{let x = 42; return x;})()"))
        XCTAssert("undefined" == iono.evalSimpleJs(source: "const myVal = 42"))
        XCTAssert("43" == iono.evalSimpleJs(source: "myVal + 1"))
        
        iono.evalNodeCode(source: "global.__iono_onMessage = (x) => { global.__iono_sendMessage(x); }")
        let message = "Hello IONO"
        iono.sendMessage(message: message)
        handler.messageSemaphore.wait()
        XCTAssert(message == handler.lastMessage)
    }

}
