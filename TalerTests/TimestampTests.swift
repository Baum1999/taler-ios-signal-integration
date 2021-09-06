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

class TimestampTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTimestamps() throws {
        let json1 = "{ \"t_ms\" : 12309487 }".data(using: .utf8)!
        let json2 = "{ \"t_ms\" : \"never\" }".data(using: .utf8)!
        let json3 = "{ \"t_ms\" : \"sometime\" }".data(using: .utf8)!
        
        var t: Timestamp = try! JSONDecoder().decode(Timestamp.self, from: json1)
        XCTAssertEqual(t, Timestamp.millisecondsSinceEpoch(12309487))
        
        t = try! JSONDecoder().decode(Timestamp.self, from: json2)
        XCTAssertEqual(t, Timestamp.never)
        XCTAssertThrowsError(t = try JSONDecoder().decode(Timestamp.self, from: json3))
    }

}
