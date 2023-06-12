/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import XCTest
@testable import taler_swift

class TimeTests: XCTestCase {
    func testParsing() {
        let json1 = "{ \"t_ms\" : 12309487 }".data(using: .utf8)!
        let json2 = "{ \"t_ms\" : \"never\" }".data(using: .utf8)!
        let json3 = "{ \"t_ms\" : \"sometime\" }".data(using: .utf8)!
        
        var t: Timestamp = try! JSONDecoder().decode(Timestamp.self, from: json1)
        XCTAssertEqual(t, Timestamp.milliseconds(12309487))
        
        t = try! JSONDecoder().decode(Timestamp.self, from: json2)
        XCTAssertEqual(t, Timestamp.never)
        XCTAssertThrowsError(t = try JSONDecoder().decode(Timestamp.self, from: json3))
    }
    
    func testSerialize() {
        let str1 = "{\"t_ms\":12309487}"
        let time1 = Timestamp.milliseconds(12309487)
        
        let str2 = "{\"t_ms\":\"never\"}"
        let time2 = Timestamp.never
        
        XCTAssert(try! String(data: JSONEncoder().encode(time1), encoding: .utf8)! == str1)
        XCTAssert(try! String(data: JSONEncoder().encode(time2), encoding: .utf8)! == str2)
    }
    
    func testTimestampDurationAdd() {
        XCTAssert(Timestamp.never + Duration.milliseconds(0) == Timestamp.never)
        XCTAssert(Timestamp.never + Duration.milliseconds(123456) == Timestamp.never)
        XCTAssert(Timestamp.never + Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(0) + Duration.milliseconds(0) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) + Duration.milliseconds(12309487) == Timestamp.milliseconds(12309487))
        XCTAssert(Timestamp.milliseconds(0) + Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.milliseconds(0) == Timestamp.milliseconds(12309487))
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.milliseconds(UInt64.max - 12309487) == Timestamp.milliseconds(UInt64.max))
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.milliseconds((UInt64.max - 12309487) + 1) == Timestamp.never)
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.forever == Timestamp.never)
    }
    
    func testTimestampDurationSubtraction() {
        XCTAssert(Timestamp.never - Duration.milliseconds(0) == Timestamp.never)
        XCTAssert(Timestamp.never - Duration.milliseconds(123456) == Timestamp.never)
        XCTAssert(Timestamp.never - Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(0) - Duration.milliseconds(0) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) - Duration.milliseconds(123456) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) - Duration.forever == Timestamp.milliseconds(0))
        
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.milliseconds(0) == Timestamp.milliseconds(12309487))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.milliseconds(487) == Timestamp.milliseconds(12309000))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.milliseconds(12309487) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.milliseconds(12309488) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.forever == Timestamp.milliseconds(0))
    }
    
    func testTimestampDifference() {
        XCTAssert(try! Timestamp.never - Timestamp.milliseconds(0) == Duration.forever)
        XCTAssert(try! Timestamp.never - Timestamp.milliseconds(123456) == Duration.forever)
        XCTAssert(try! Timestamp.never - Timestamp.never == Duration.forever)
        
        XCTAssert(try! Timestamp.milliseconds(0) - Timestamp.milliseconds(0) == Duration.milliseconds(0))
        XCTAssert(try! Timestamp.milliseconds(0) - Timestamp.milliseconds(123456) == Duration.milliseconds(0))
        XCTAssertThrowsError(try Timestamp.milliseconds(0) - Timestamp.never)
        
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(0) == Duration.milliseconds(12309487))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309000) == Duration.milliseconds(487))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309487) == Duration.milliseconds(0))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309488) == Duration.milliseconds(0))
        XCTAssertThrowsError(try Timestamp.milliseconds(12309487) - Timestamp.never)
    }
}
