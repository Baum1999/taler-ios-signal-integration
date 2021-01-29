//
//  NodeWrapperTests.swift
//  TalerTests
//
//  Created by Jonathan Buchanan on 1/14/21.
//  Copyright © 2021 Taler. All rights reserved.
//

import XCTest
@testable import Taler

class NodeWrapperTests: XCTestCase {
    var iono: Iono!
    
    override func setUpWithError() throws {
        iono = Iono()
    }

    override func tearDownWithError() throws {
        
    }

    func testEvalJS() throws {
        XCTAssert("2" == iono.evalJS(source: "1 + 1"))
        XCTAssert("36" == iono.evalJS(source: "6 * 6"))
        XCTAssert("42" == iono.evalJS(source: "(()=>{let x = 42; return x;})()"))
        XCTAssert("undefined" == iono.evalJS(source: "const myVal = 42"))
        XCTAssert("43" == iono.evalJS(source: "myVal + 1"))
    }

}
