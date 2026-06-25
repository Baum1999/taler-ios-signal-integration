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

@MainActor
final class OrderManagerTests: XCTestCase {

    private var orderManager: OrderManager!

    private let posConfig = PosConfig(
        categories: [
            Category(id: 1, name: "one"),
            Category(id: 2, name: "two"),
        ],
        products: [
            ConfigProduct(
                description: "foo",
                price: Amount(currency: "KUDOS", value: 1, fraction: 0),
                categories: [1]
            ),
            ConfigProduct(
                description: "bar",
                price: Amount(currency: "KUDOS", value: 1, fraction: 50000000),
                categories: [2]
            ),
        ]
    )

    override func setUp() {
        super.setUp()
        orderManager = OrderManager()
    }

    func testConfigErrorOnMissingCategories() {
        let config = PosConfig(categories: [], products: posConfig.products)
        let result = orderManager.onConfigurationReceived(
            posConfig: config, currency: "KUDOS", currencySpec: nil
        )
        XCTAssertNotNil(result)
    }

    func testCurrencyMismatchProductIsAcceptedButUnavailable() {
        let products = [
            ConfigProduct(
                description: "foo",
                price: Amount(currency: "WRONGCUR", value: 1, fraction: 0),
                categories: [1]
            )
        ]
        let config = PosConfig(categories: posConfig.categories, products: products)
        let result = orderManager.onConfigurationReceived(
            posConfig: config, currency: "KUDOS", currencySpec: nil
        )

        XCTAssertNil(result)
        let product = orderManager.products.first { $0.description == "foo" }
        XCTAssertNotNil(product)
        XCTAssertEqual("WRONGCUR", product?.price.currency)
        XCTAssertTrue(product?.currencyMismatch == true)
        XCTAssertFalse(product?.availableToSell == true)
    }

    func testValidConfigGetsAccepted() {
        let result = orderManager.onConfigurationReceived(
            posConfig: posConfig, currency: "KUDOS", currencySpec: nil
        )
        XCTAssertNil(result)
    }

    func testAllObjectsIsSelectedByDefaultAndShownFirst() {
        let result = orderManager.onConfigurationReceived(
            posConfig: posConfig, currency: "KUDOS", currencySpec: nil
        )
        XCTAssertNil(result)

        let categories = orderManager.categories
        let products = orderManager.products

        XCTAssertFalse(categories.isEmpty)
        XCTAssertFalse(products.isEmpty)
        XCTAssertTrue(categories[0].selected)
        XCTAssertFalse(categories[1].selected)
        XCTAssertEqual(posConfig.products.count, products.count)
    }

    func testUncategorizedIsAppendedAtTheEndWhenNeeded() {
        let uncategorizedProduct = ConfigProduct(
            description: "baz",
            price: Amount(currency: "KUDOS", value: 2, fraction: 0),
            categories: []
        )
        let config = PosConfig(
            categories: posConfig.categories,
            products: posConfig.products + [uncategorizedProduct]
        )

        let result = orderManager.onConfigurationReceived(
            posConfig: config, currency: "KUDOS", currencySpec: nil
        )
        XCTAssertNil(result)

        let categories = orderManager.categories
        let uncategorized = categories.last!
        XCTAssertEqual(uncategorized.id, -2)

        orderManager.selectCategory(uncategorized)
        let uncatProducts = orderManager.products
        XCTAssertEqual(1, uncatProducts.count)
        XCTAssertEqual("baz", uncatProducts[0].description)
    }

    func testLegacyDefaultCategoryIsHiddenAndMappedToUncategorized() {
        let defaultCategory = Category(id: 3, name: "Default")
        let defaultProduct = ConfigProduct(
            description: "legacy",
            price: Amount(currency: "KUDOS", value: 3, fraction: 0),
            categories: [3]
        )
        let config = PosConfig(
            categories: posConfig.categories + [defaultCategory],
            products: posConfig.products + [defaultProduct]
        )

        let result = orderManager.onConfigurationReceived(
            posConfig: config, currency: "KUDOS", currencySpec: nil
        )
        XCTAssertNil(result)

        let categories = orderManager.categories
        XCTAssertFalse(categories.contains(where: { $0.name == "Default" }))

        let uncategorized = categories.last!
        XCTAssertEqual(uncategorized.id, -2)

        orderManager.selectCategory(uncategorized)
        let uncatProducts = orderManager.products
        XCTAssertEqual(1, uncatProducts.count)
        XCTAssertEqual("legacy", uncatProducts[0].description)
    }
}
