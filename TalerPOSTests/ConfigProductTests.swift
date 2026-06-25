/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import XCTest
@testable import TalerPOS

final class ConfigProductTests: XCTestCase {

    func testDisplayDescriptionIsHiddenWhenSameAsProductName() {
        let product = ConfigProduct(
            productName: "Coffee",
            description: "Coffee",
            price: Amount(currency: "KUDOS", value: 2, fraction: 0),
            categories: [1]
        )

        XCTAssertEqual("Coffee", product.displayName)
        XCTAssertNil(product.displayDescription)
    }

    func testDisplayPriceFormatsAmount() {
        let product = ConfigProduct(
            description: "Coffee",
            price: Amount(currency: "KUDOS", value: 2, fraction: 50000000),
            categories: [1]
        )

        XCTAssertEqual("2.50 KUDOS", product.price.readableAmount)
    }

    func testStockLimitSubtractsSoldAndLostFromTotalStock() {
        let product = ConfigProduct(
            description: "finite_quantity",
            price: Amount(currency: "KUDOS", value: 10, fraction: 0),
            categories: [],
            totalStock: 10,
            unitTotalStock: "10",
            totalSold: 0,
            totalLost: 2
        )

        XCTAssertEqual(8, product.stockLimit)
    }

    func testStockLimitSubtractsUnitSoldAndLost() {
        let product = ConfigProduct(
            description: "test",
            price: Amount(currency: "KUDOS", value: 5, fraction: 0),
            categories: [],
            unitTotalStock: "10",
            unitTotalSold: "2",
            unitTotalLost: "3"
        )

        XCTAssertEqual(5, product.stockLimit)
    }

    func testStockLimitWithNoSoldOrLostReturnsTotalStock() {
        let product = ConfigProduct(
            description: "test",
            price: Amount(currency: "KUDOS", value: 5, fraction: 0),
            categories: [],
            totalStock: 10
        )

        XCTAssertEqual(10, product.stockLimit)
    }

    func testStockLimitReturnsNilForUnlimitedStock() {
        let product = ConfigProduct(
            description: "test",
            price: Amount(currency: "KUDOS", value: 5, fraction: 0),
            categories: [],
            totalStock: -1
        )

        XCTAssertNil(product.stockLimit)
    }

    func testStockLimitClampsToZeroWhenSoldAndLostExceedStock() {
        let product = ConfigProduct(
            description: "test",
            price: Amount(currency: "KUDOS", value: 5, fraction: 0),
            categories: [],
            totalStock: 5,
            totalSold: 3,
            totalLost: 5
        )

        XCTAssertEqual(0, product.stockLimit)
    }
}
