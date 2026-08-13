/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import XCTest
@testable import taler_swift

class TimeTests: XCTestCase {
    func testParsing() {
        // The protocol wire format is TalerProtocolTimestamp: {"t_s": <seconds>} with the
        // string sentinel "never". The legacy {"t_ms": ...} form is still accepted for
        // numbers only (see testParsingLegacyMilliseconds).
        let json1 = "{ \"t_s\" : 12309 }".data(using: .utf8)!
        let json2 = "{ \"t_s\" : \"never\" }".data(using: .utf8)!
        let json3 = "{ \"t_s\" : \"sometime\" }".data(using: .utf8)!

        var t: Timestamp = try! JSONDecoder().decode(Timestamp.self, from: json1)
        XCTAssertEqual(t, Timestamp.milliseconds(12309 * 1000))

        t = try! JSONDecoder().decode(Timestamp.self, from: json2)
        XCTAssertEqual(t, Timestamp.never)
        XCTAssertThrowsError(t = try JSONDecoder().decode(Timestamp.self, from: json3))
    }

    func testParsingLegacyMilliseconds() {
        // A numeric legacy t_ms still decodes...
        let json1 = "{ \"t_ms\" : 12309487 }".data(using: .utf8)!
        let t: Timestamp = try! JSONDecoder().decode(Timestamp.self, from: json1)
        XCTAssertEqual(t, Timestamp.milliseconds(12309487))
        // ...but "never" under the legacy key does NOT: the fallback in
        // Timestamp.init(from:) only ever looks for the string sentinel under `t_s`.
        // Documented here as current behaviour, not endorsed — see bugs.txt.
        let json2 = "{ \"t_ms\" : \"never\" }".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Timestamp.self, from: json2))
    }

    func testSerialize() {
        // Encoding is lossy: milliseconds are truncated to whole seconds (see bugs.txt),
        // so a round trip only holds for whole-second timestamps.
        let str1 = "{\"t_s\":12309}"
        let time1 = Timestamp.milliseconds(12309 * 1000)

        let str2 = "{\"t_s\":\"never\"}"
        let time2 = Timestamp.never
        
        XCTAssert(try! String(data: JSONEncoder().encode(time1), encoding: .utf8)! == str1)
        XCTAssert(try! String(data: JSONEncoder().encode(time2), encoding: .utf8)! == str2)
    }
    
    func testTimestampDurationAdd() {
        XCTAssert(Timestamp.never + Duration.microseconds((0) * 1000) == Timestamp.never)
        XCTAssert(Timestamp.never + Duration.microseconds((123456) * 1000) == Timestamp.never)
        XCTAssert(Timestamp.never + Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(0) + Duration.microseconds((0) * 1000) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) + Duration.microseconds((12309487) * 1000) == Timestamp.milliseconds(12309487))
        XCTAssert(Timestamp.milliseconds(0) + Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.microseconds((0) * 1000) == Timestamp.milliseconds(12309487))
        // Duration is microseconds, Timestamp is milliseconds, and `+` divides the addend
        // by 1000. So the largest addend any Duration can express is UInt64.max/1000 ms —
        // which means the overflow boundary now sits near the top of the *Timestamp* range,
        // not near the addend. Test the exact boundary and one millisecond past it.
        let maxAddendMs = UInt64.max / 1000
        XCTAssert(Timestamp.milliseconds(UInt64.max - maxAddendMs) + Duration.microseconds(UInt64.max) == Timestamp.milliseconds(UInt64.max))
        XCTAssert(Timestamp.milliseconds(UInt64.max - maxAddendMs + 1) + Duration.microseconds(UInt64.max) == Timestamp.never)
        XCTAssert(Timestamp.milliseconds(12309487) + Duration.forever == Timestamp.never)
    }
    
    func testTimestampDurationSubtraction() {
        XCTAssert(Timestamp.never - Duration.microseconds((0) * 1000) == Timestamp.never)
        XCTAssert(Timestamp.never - Duration.microseconds((123456) * 1000) == Timestamp.never)
        XCTAssert(Timestamp.never - Duration.forever == Timestamp.never)
        
        XCTAssert(Timestamp.milliseconds(0) - Duration.microseconds((0) * 1000) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) - Duration.microseconds((123456) * 1000) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(0) - Duration.forever == Timestamp.milliseconds(0))
        
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.microseconds((0) * 1000) == Timestamp.milliseconds(12309487))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.microseconds((487) * 1000) == Timestamp.milliseconds(12309000))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.microseconds((12309487) * 1000) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.microseconds((12309488) * 1000) == Timestamp.milliseconds(0))
        XCTAssert(Timestamp.milliseconds(12309487) - Duration.forever == Timestamp.milliseconds(0))
    }
    
    func testTimestampDifference() {
        XCTAssert(try! Timestamp.never - Timestamp.milliseconds(0) == Duration.forever)
        XCTAssert(try! Timestamp.never - Timestamp.milliseconds(123456) == Duration.forever)
        XCTAssert(try! Timestamp.never - Timestamp.never == Duration.forever)
        
        XCTAssert(try! Timestamp.milliseconds(0) - Timestamp.milliseconds(0) == Duration.microseconds((0) * 1000))
        XCTAssert(try! Timestamp.milliseconds(0) - Timestamp.milliseconds(123456) == Duration.microseconds((0) * 1000))
        XCTAssertThrowsError(try Timestamp.milliseconds(0) - Timestamp.never)
        
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(0) == Duration.microseconds((12309487) * 1000))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309000) == Duration.microseconds((487) * 1000))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309487) == Duration.microseconds((0) * 1000))
        XCTAssert(try! Timestamp.milliseconds(12309487) - Timestamp.milliseconds(12309488) == Duration.microseconds((0) * 1000))
        XCTAssertThrowsError(try Timestamp.milliseconds(12309487) - Timestamp.never)
    }
}
