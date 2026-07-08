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
    case login = "login"
    case mfaSelect = "mfa-select"
    case mfaCode = "mfa-code"
    case amountEntry = "amount-entry"
    case order = "order"
    case orderCustom = "order-custom"
    case orderCustomAdded = "order-custom-added"
    case payment = "payment"
    case paymentSuccess = "payment-success"
    case history = "history"
    case refund = "refund"
    case refundQr = "refund-qr"
    case navigation = "navigation"
    case settings = "settings"

    var destination: PosDestination {
        switch self {
        case .login, .mfaSelect, .mfaCode: return .config
        case .amountEntry: return .amountEntry
        case .order, .orderCustom, .orderCustomAdded: return .order
        case .payment: return .processPayment
        case .paymentSuccess: return .paymentSuccess
        case .history: return .history
        case .refund: return .history
        case .refundQr: return .history
        case .navigation: return .order
        case .settings: return .settings
        }
    }

    var isConfigScreen: Bool {
        switch self {
        case .login, .mfaSelect, .mfaCode: return true
        default: return false
        }
    }
}

@MainActor
enum ScreenshotController {
    private static let launchArgument = "SCREENSHOT_SCENARIO"
    private static let localeArgument = "SCREENSHOT_LOCALE"
    private static let currency = "CHF"

    static var activeScenario: ScreenshotScenario? {
        guard let value = ProcessInfo.processInfo.environment[launchArgument]
                ?? parseLaunchArgument(launchArgument) else { return nil }
        return ScreenshotScenario(rawValue: value)
    }

    static var isActive: Bool { activeScenario != nil }
    static var showCustomDialog: Bool { activeScenario == .orderCustom }
    static var showDrawer: Bool { activeScenario == .navigation }
    static var showMfaSelect: Bool { activeScenario == .mfaSelect }
    static var showMfaCode: Bool { activeScenario == .mfaCode }

    static var mfaMockChallenges: [MfaChallenge] {
        [
            MfaChallenge(challengeId: "ch-sms-1", tanChannel: .sms, tanInfo: "+41 79 *** ** 42"),
            MfaChallenge(challengeId: "ch-email-1", tanChannel: .email, tanInfo: "m***@example.com"),
        ]
    }

    static var mfaMockTanChallenge: MfaChallenge {
        MfaChallenge(challengeId: "ch-sms-1", tanChannel: .sms, tanInfo: "+41 79 *** ** 42")
    }

    static func applyLocaleIfNeeded() {
        guard let tag = ProcessInfo.processInfo.environment[localeArgument]
                ?? parseLaunchArgument(localeArgument),
              !tag.isEmpty else { return }
        LanguageManager.shared.setLanguage(tag)
    }

    private static func parseLaunchArgument(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-\(key)"),
              idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    static func applyFixture(
        configManager: ConfigManager,
        orderManager: OrderManager,
        paymentManager: PaymentManager,
        historyManager: HistoryManager,
        refundManager: RefundManager,
        scenario: ScreenshotScenario
    ) {
        if scenario.isConfigScreen {
            configManager.merchantUrl = "backend.demo.taler.net"
            return
        }

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

        switch scenario {
        case .order, .orderCustom, .orderCustomAdded, .navigation:
            seedOrder(orderManager: orderManager, productIds: [
                "lemonade", "lemonade", "lemonade", "lemonade", "lemonade",
                "wrap", "wrap",
                "chips",
                "salad", "salad",
            ])
        default:
            seedOrder(orderManager: orderManager, productIds: ["coffee", "croissant", "sandwich", "coffee"])
        }

        switch scenario {
        case .login, .mfaSelect, .mfaCode:
            break
        case .amountEntry, .order, .navigation, .settings:
            break
        case .orderCustom:
            break
        case .orderCustomAdded:
            if let liveOrder = orderManager.currentLiveOrder {
                let customProduct = ConfigProduct(
                    description: S.orderCustomProductDefault,
                    price: Amount(currency: currency, value: 2, fraction: 73000000),
                    categories: [Int.min],
                    quantity: 1
                )
                orderManager.addProduct(orderId: liveOrder.id, product: customProduct)
            }
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
        case .history:
            seedHistory(historyManager: historyManager)
        case .refund:
            let item = buildRefundItem()
            refundManager.startRefund(item: item)
        case .refundQr:
            let item = buildRefundItem()
            refundManager.refundResult = .success(
                refundUri: "taler://refund/example.invalid/2026-ORD-1047/REFUND-ABC123",
                item: item,
                amount: Amount(currency: currency, value: 18, fraction: 30000000),
                reason: S.orderCustomProductDefault
            )
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

    private static func seedHistory(historyManager: HistoryManager) {
        let now = UInt64(Date().timeIntervalSince1970)
        historyManager.items = [
            OrderHistoryEntry(
                orderId: "2026-ORD-1048",
                rowId: 48,
                timestamp: Timestamp(seconds: now - 60),
                amount: Amount(currency: currency, value: 12, fraction: 40000000),
                summary: "Chicken Wrap + Lemonade",
                paid: false,
                refundable: false
            ),
            OrderHistoryEntry(
                orderId: "2026-ORD-1047",
                rowId: 47,
                timestamp: Timestamp(seconds: now - 300),
                amount: Amount(currency: currency, value: 18, fraction: 30000000),
                summary: "Veggie Sandwich + House Coffee",
                paid: true,
                refundable: true
            ),
            OrderHistoryEntry(
                orderId: "2026-ORD-1046",
                rowId: 46,
                timestamp: Timestamp(seconds: now - 900),
                amount: Amount(currency: currency, value: 6, fraction: 70000000),
                summary: "Butter Croissant + Herbal Tea",
                paid: true,
                refundable: true,
                pendingRefundAmount: Amount(currency: currency, value: 6, fraction: 70000000),
                refundPending: true
            ),
            OrderHistoryEntry(
                orderId: "2026-ORD-1045",
                rowId: 45,
                timestamp: Timestamp(seconds: now - 1800),
                amount: Amount(currency: currency, value: 3, fraction: 80000000),
                summary: "House Coffee",
                paid: true,
                refundable: false,
                refunded: true,
                refundAmount: Amount(currency: currency, value: 3, fraction: 80000000)
            ),
        ]
    }

    private static func buildRefundItem() -> OrderHistoryEntry {
        OrderHistoryEntry(
            orderId: "2026-ORD-1047",
            rowId: 47,
            timestamp: Timestamp(seconds: UInt64(Date().timeIntervalSince1970)),
            amount: Amount(currency: currency, value: 18, fraction: 30000000),
            summary: "Veggie Sandwich + House Coffee",
            paid: true,
            refundable: true
        )
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
            Category(id: 4, name: "Snacks"),
            Category(id: 5, name: "Specials"),
        ]
        let products = [
            ConfigProduct(
                id: "coffee",
                productId: "coffee",
                productName: "House Coffee",
                description: "Freshly brewed fair-trade blend",
                price: Amount(currency: currency, value: 3, fraction: 80000000),
                image: imageDataUri("coffee"),
                categories: [1]
            ),
            ConfigProduct(
                id: "tea",
                productId: "tea",
                productName: "Herbal Tea",
                description: "Mint and lemon verbena infusion",
                price: Amount(currency: currency, value: 3, fraction: 40000000),
                image: imageDataUri("tea"),
                categories: [1]
            ),
            ConfigProduct(
                id: "juice",
                productId: "juice",
                productName: "Apple Juice",
                description: "Pressed Swiss apples, 30 cl",
                price: Amount(currency: currency, value: 4, fraction: 20000000),
                image: imageDataUri("juice"),
                categories: [1]
            ),
            ConfigProduct(
                id: "espresso",
                productId: "espresso",
                productName: "Espresso",
                description: "Single origin, short pull",
                price: Amount(currency: currency, value: 3, fraction: 20000000),
                image: imageDataUri("espresso"),
                categories: [1]
            ),
            ConfigProduct(
                id: "lemonade",
                productId: "lemonade",
                productName: "Lemonade",
                description: "Sparkling lemon and ginger",
                price: Amount(currency: currency, value: 4, fraction: 40000000),
                image: imageDataUri("lemonade"),
                categories: [1, 5]
            ),
            ConfigProduct(
                id: "croissant",
                productId: "croissant",
                productName: "Butter Croissant",
                description: "All-butter pastry baked this morning",
                price: Amount(currency: currency, value: 2, fraction: 90000000),
                image: imageDataUri("croissant"),
                categories: [2]
            ),
            ConfigProduct(
                id: "muffin",
                productId: "muffin",
                productName: "Blueberry Muffin",
                description: "With lemon crumble topping",
                price: Amount(currency: currency, value: 4, fraction: 60000000),
                image: imageDataUri("muffin"),
                categories: [2, 4]
            ),
            ConfigProduct(
                id: "bagel",
                productId: "bagel",
                productName: "Sesame Bagel",
                description: "Toasted with cream cheese",
                price: Amount(currency: currency, value: 5, fraction: 20000000),
                image: imageDataUri("bagel"),
                categories: [2]
            ),
            ConfigProduct(
                id: "sandwich",
                productId: "sandwich",
                productName: "Veggie Sandwich",
                description: "Grilled vegetables, hummus, seeded roll",
                price: Amount(currency: currency, value: 8, fraction: 50000000),
                image: imageDataUri("sandwich"),
                categories: [3]
            ),
            ConfigProduct(
                id: "wrap",
                productId: "wrap",
                productName: "Chicken Wrap",
                description: "Herbs, salad, yogurt dressing",
                price: Amount(currency: currency, value: 8, fraction: 90000000),
                image: imageDataUri("wrap"),
                categories: [3]
            ),
            ConfigProduct(
                id: "salad",
                productId: "salad",
                productName: "Garden Salad",
                description: "Mixed greens with vinaigrette",
                price: Amount(currency: currency, value: 7, fraction: 50000000),
                image: imageDataUri("salad"),
                categories: [3, 5]
            ),
            ConfigProduct(
                id: "soup",
                productId: "soup",
                productName: "Pumpkin Soup",
                description: "Seasonal special, served warm",
                price: Amount(currency: currency, value: 7, fraction: 20000000),
                image: imageDataUri("soup"),
                categories: [3, 5],
                totalStock: 0
            ),
            ConfigProduct(
                id: "quiche",
                productId: "quiche",
                productName: "Quiche Lorraine",
                description: "Classic egg and bacon tart",
                price: Amount(currency: currency, value: 7, fraction: 20000000),
                image: imageDataUri("quiche"),
                categories: [3, 5]
            ),
            ConfigProduct(
                id: "granola",
                productId: "granola",
                productName: "Granola Bowl",
                description: "Oats, nuts, seasonal berries",
                price: Amount(currency: currency, value: 5, fraction: 90000000),
                image: imageDataUri("granola"),
                categories: [4, 5]
            ),
            ConfigProduct(
                id: "chips",
                productId: "chips",
                productName: "Veggie Chips",
                description: "Root vegetable crisps, sea salt",
                price: Amount(currency: currency, value: 3, fraction: 50000000),
                image: imageDataUri("chips"),
                categories: [4]
            ),
            ConfigProduct(
                id: "fruit",
                productId: "fruit",
                productName: "Fresh Fruit Cup",
                description: "Seasonal sliced fruit mix",
                price: Amount(currency: currency, value: 4, fraction: 80000000),
                image: imageDataUri("fruit"),
                categories: [4, 5]
            ),
        ]
        return PosConfig(categories: categories, products: products)
    }
}
