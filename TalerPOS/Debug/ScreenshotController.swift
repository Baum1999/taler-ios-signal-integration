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

import Foundation

enum ScreenshotScenario: String, CaseIterable {
    case amountEntry = "amount-entry"
    case order = "order"
    case payment = "payment"
    case paymentSuccess = "payment-success"

    var destination: PosDestination {
        switch self {
        case .amountEntry: return .amountEntry
        case .order: return .order
        case .payment: return .processPayment
        case .paymentSuccess: return .paymentSuccess
        }
    }
}

@MainActor
enum ScreenshotController {
    private static let launchArgument = "SCREENSHOT_SCENARIO"
    private static let currency = "CHF"

    static var activeScenario: ScreenshotScenario? {
        guard let value = ProcessInfo.processInfo.environment[launchArgument]
                ?? parseLaunchArgument() else { return nil }
        return ScreenshotScenario(rawValue: value)
    }

    static var isActive: Bool { activeScenario != nil }

    private static func parseLaunchArgument() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-\(launchArgument)"),
              idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    static func applyFixture(
        configManager: ConfigManager,
        orderManager: OrderManager,
        paymentManager: PaymentManager,
        scenario: ScreenshotScenario
    ) {
        let fixture = buildFixture()
        configManager.merchantUrl = "https://merchant.example.invalid/instances/demo"
        configManager.accessToken = "screenshot-fixture"
        configManager.merchantConfig = MerchantConfig(
            baseUrl: "https://merchant.example.invalid/instances/demo",
            apiKey: ""
        )
        configManager.currency = currency

        _ = orderManager.onConfigurationReceived(
            posConfig: fixture,
            currency: currency,
            currencySpec: nil
        )

        seedOrder(orderManager: orderManager, productIds: ["coffee", "croissant", "sandwich", "coffee"])

        switch scenario {
        case .amountEntry, .order:
            break
        case .payment:
            if let liveOrder = orderManager.currentLiveOrder {
                paymentManager.payment = Payment(
                    order: liveOrder.order,
                    summary: liveOrder.order.summary,
                    currency: currency,
                    origin: .inventory,
                    orderId: "2026-ORD-1042",
                    talerPayUri: "taler://pay/example.invalid/2026-ORD-1042/ZXCVBNM123456"
                )
            }
        case .paymentSuccess:
            if let liveOrder = orderManager.currentLiveOrder {
                paymentManager.payment = Payment(
                    order: liveOrder.order,
                    summary: liveOrder.order.summary,
                    currency: currency,
                    origin: .inventory,
                    orderId: "2026-ORD-1042",
                    paid: true
                )
            }
        }
    }

    private static func seedOrder(orderManager: OrderManager, productIds: [String]) {
        guard let liveOrder = orderManager.currentLiveOrder else { return }
        for pid in productIds {
            if let product = orderManager.products.first(where: { $0.productId == pid }) {
                liveOrder.addProduct(product)
            }
        }
    }

    private static func imageDataUri(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    private static func buildFixture() -> PosConfig {
        let categories = [
            Category(id: 1, name: "Drinks"),
            Category(id: 2, name: "Bakery"),
            Category(id: 3, name: "Lunch"),
        ]
        let products = [
            ConfigProduct(
                id: "coffee",
                productId: "coffee",
                productName: "House Coffee",
                description: "House Coffee",
                price: Amount(currency: currency, value: 3, fraction: 80000000),
                image: imageDataUri("coffee"),
                categories: [1]
            ),
            ConfigProduct(
                id: "tea",
                productId: "tea",
                productName: "Herbal Tea",
                description: "Herbal Tea",
                price: Amount(currency: currency, value: 3, fraction: 40000000),
                image: imageDataUri("tea"),
                categories: [1]
            ),
            ConfigProduct(
                id: "croissant",
                productId: "croissant",
                productName: "Butter Croissant",
                description: "Butter Croissant",
                price: Amount(currency: currency, value: 2, fraction: 90000000),
                image: imageDataUri("croissant"),
                categories: [2]
            ),
            ConfigProduct(
                id: "sandwich",
                productId: "sandwich",
                productName: "Veggie Sandwich",
                description: "Veggie Sandwich",
                price: Amount(currency: currency, value: 8, fraction: 50000000),
                image: imageDataUri("sandwich"),
                categories: [3]
            ),
        ]
        return PosConfig(categories: categories, products: products)
    }
}
