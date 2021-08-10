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

class AmountTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAmounts() throws {
        var amount: Amount = try! Amount(fromString: "EUR:633.59")
        XCTAssert(amount.currency == "EUR")
        XCTAssert(amount.value == 633)
        XCTAssert(amount.fraction == 59000000)
        XCTAssert(amount.description == "EUR:633.59")
        XCTAssert(try amount == Amount(currency: "EUR", value: 633, fraction: 59000000))
        XCTAssert(try amount == amount)
        
        amount = try! Amount(fromString: "EUR:883")
        XCTAssert(amount.currency == "EUR")
        XCTAssert(amount.value == 883)
        XCTAssert(amount.fraction == 0)
        XCTAssert(amount.description == "EUR:883")
        
        XCTAssertThrowsError(try Amount(fromString: "EUR:6548$f.59.**"))
        
        let amount2: Amount = try! Amount(fromString: "EUR:971.32")
        XCTAssert(try amount < amount2)
        XCTAssert(try amount2 > amount)
        XCTAssert(try (amount + amount2) == Amount(fromString: "EUR:1854.32"))
        XCTAssert(try (amount2 - amount) == Amount(fromString: "EUR:88.32"))
        XCTAssertThrowsError(try amount - amount2)
        
        let amount3: Amount = try! Amount(fromString: "USD:12.34")
        XCTAssertThrowsError(try amount == amount3)
        XCTAssertThrowsError(try amount < amount3)
        XCTAssertThrowsError(try amount > amount3)
        XCTAssertThrowsError(try amount + amount3)
        XCTAssertThrowsError(try amount - amount3)
        
        XCTAssertThrowsError(try amount3 / 0)
        XCTAssert(try (amount3 / 1) == amount3)
        XCTAssert(try (amount3 / 3) == Amount(fromString: "USD:4.11333333"))
        XCTAssert(try (amount3 * 5) == Amount(fromString: "USD:61.7"))
    }

}
