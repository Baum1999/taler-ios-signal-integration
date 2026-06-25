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
import Combine

private let allProductsCategoryId = -1
private let uncategorizedCategoryId = -2
private let legacyDefaultCategoryName = "Default"

enum RestartState { case enabled, disabled, undo }

@MainActor
class LiveOrder: ObservableObject, Identifiable {
    let id: Int
    private let currency: String
    private let productsByCategory: [Category: [ConfigProduct]]
    private let canAddProductCheck: (ConfigProduct) -> Bool
    private let onChanged: () -> Void

    @Published var order: Order
    @Published var restartState: RestartState = .disabled
    @Published var selectedOrderLine: ConfigProduct?
    var lastAddedProduct: ConfigProduct?
    private var undoOrder: Order?

    var availableCategories: [Int: Category] {
        Dictionary(uniqueKeysWithValues: productsByCategory.keys.map { ($0.id, $0) })
    }

    var orderTotal: Amount { order.total }

    var modifyOrderAllowed: Bool {
        restartState != .disabled && selectedOrderLine != nil
    }

    var increaseOrderAllowed: Bool {
        guard let selected = selectedOrderLine else { return false }
        return canAddProductCheck(selected)
    }

    var selectedProductKey: String? {
        selectedOrderLine?.id
    }

    init(
        id: Int,
        currency: String,
        productsByCategory: [Category: [ConfigProduct]],
        canAddProduct: @escaping (ConfigProduct) -> Bool,
        onChanged: @escaping () -> Void
    ) {
        self.id = id
        self.currency = currency
        self.productsByCategory = productsByCategory
        self.canAddProductCheck = canAddProduct
        self.onChanged = onChanged
        self.order = Order(id: id, currency: currency, availableCategories: Dictionary(uniqueKeysWithValues: productsByCategory.keys.map { ($0.id, $0) }), products: [])
    }

    func addProduct(_ product: ConfigProduct) {
        guard canAddProductCheck(product) else { return }
        lastAddedProduct = product
        order = order.adding(product)
        restartState = .enabled
        repairSelection()
        onChanged()
    }

    func removeProduct(_ product: ConfigProduct) {
        order = order.removing(product)
        restartState = order.products.isEmpty ? .disabled : .enabled
        repairSelection()
        onChanged()
    }

    var isEmpty: Bool { order.products.isEmpty }

    func restartOrUndo() {
        if restartState == .undo {
            if let undo = undoOrder {
                order = undo
                restartState = .enabled
                undoOrder = nil
            }
        } else {
            undoOrder = order
            order = Order(id: id, currency: currency, availableCategories: availableCategories, products: [])
            restartState = .undo
        }
        repairSelection()
        onChanged()
    }

    func selectOrderLine(_ product: ConfigProduct?) {
        selectedOrderLine = product
    }

    func repairSelection() {
        let products = order.products
        if products.isEmpty {
            selectedOrderLine = nil
            return
        }
        if let lastAdded = lastAddedProduct, products.contains(where: { $0.id == lastAdded.id }) {
            selectedOrderLine = products.first(where: { $0.id == lastAdded.id })
        } else if let current = selectedOrderLine, products.contains(where: { $0.id == current.id }) {
            selectedOrderLine = products.first(where: { $0.id == current.id })
        } else {
            selectedOrderLine = products.last
        }
    }

    func increaseSelectedOrderLine() {
        guard let orderLine = selectedOrderLine else { return }
        addProduct(orderLine)
    }

    func decreaseSelectedOrderLine() {
        guard let orderLine = selectedOrderLine else { return }
        removeProduct(orderLine)
    }
}

@MainActor
class OrderManager: ObservableObject, ConfigurationReceiver {
    @Published var categories: [Category] = []
    @Published var products: [ConfigProduct] = []
    @Published var currentOrderId: Int = 0

    private var currency: String = ""
    private var currencySpec: CurrencySpecification?
    private var productsByCategory: [Category: [ConfigProduct]] = [:]
    private var productsById: [String: ConfigProduct] = [:]
    private var currentCategory: Category?
    private var orders: OrderedDictionary<Int, LiveOrder> = OrderedDictionary()
    private var orderCounter: Int = 0

    var currentLiveOrder: LiveOrder? {
        orders[currentOrderId]
    }

    func getOrder(_ orderId: Int) -> LiveOrder? {
        orders[orderId]
    }

    func onConfigurationReceived(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?) -> String? {
        return applyConfiguration(posConfig: posConfig, currency: currency, currencySpec: currencySpec, resetOrders: true)
    }

    func onInventoryUpdated(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?) -> String? {
        return applyConfiguration(posConfig: posConfig, currency: currency, currencySpec: currencySpec, resetOrders: false)
    }

    private func applyConfiguration(posConfig: PosConfig, currency: String, currencySpec: CurrencySpecification?, resetOrders: Bool) -> String? {
        let existingProductsByStableKey = Dictionary(
            productsById.values.map { ($0.stableKey, $0) },
            uniquingKeysWith: { _, last in last }
        )

        guard !posConfig.categories.isEmpty else {
            return "No valid category found."
        }

        let selectedCategoryId = resetOrders ? allProductsCategoryId : currentCategory?.id
        let allProductsCategory = Category(id: allProductsCategoryId, name: S.productCategoryAll)
        let uncategorizedCategory = Category(id: uncategorizedCategoryId, name: S.productCategoryUncategorized)
        let visibleCategories = posConfig.categories.filter { !isLegacyDefaultCategory($0) }
        let legacyDefaultCategoryIds = Set(
            posConfig.categories.filter { isLegacyDefaultCategory($0) }.map { $0.id }
        )

        productsByCategory.removeAll()
        productsById.removeAll()
        productsByCategory[allProductsCategory] = []
        for cat in visibleCategories {
            productsByCategory[cat] = []
        }
        productsByCategory[uncategorizedCategory] = []

        for product in posConfig.products {
            let currencyMismatch = product.price.currency != currency
            let remainingStock = product.stockLimit
            let preservedId = existingProductsByStableKey[product.stableKey]?.id ?? product.id
            var p = ConfigProduct(
                id: preservedId,
                productId: product.productId,
                productName: product.productName,
                description: product.description,
                descriptionI18n: product.descriptionI18n,
                price: product.price,
                pricesAreNet: product.pricesAreNet,
                location: product.location,
                image: product.image,
                taxes: product.taxes,
                categories: product.categories,
                quantity: product.quantity,
                totalStock: product.totalStock,
                unitTotalStock: product.unitTotalStock,
                totalSold: product.totalSold,
                unitTotalSold: product.unitTotalSold,
                totalLost: product.totalLost,
                unitTotalLost: product.unitTotalLost,
                availableToSell: !currencyMismatch && (remainingStock == nil || remainingStock! > 0),
                remainingStock: remainingStock,
                currencyMismatch: currencyMismatch
            )

            productsById[p.id] = p
            productsByCategory[allProductsCategory]?.append(p)

            if p.categories.isEmpty {
                productsByCategory[uncategorizedCategory]?.append(p)
            }
            for catId in p.categories {
                if legacyDefaultCategoryIds.contains(catId) {
                    productsByCategory[uncategorizedCategory]?.append(p)
                    continue
                }
                if let cat = visibleCategories.first(where: { $0.id == catId }) {
                    productsByCategory[cat]?.append(p)
                } else {
                    productsByCategory[uncategorizedCategory]?.append(p)
                }
            }
        }

        self.currency = currency
        self.currencySpec = currencySpec

        var categoryList = [allProductsCategory] + visibleCategories
        if let uncatProducts = productsByCategory[uncategorizedCategory], !uncatProducts.isEmpty {
            categoryList.append(uncategorizedCategory)
        } else {
            productsByCategory.removeValue(forKey: uncategorizedCategory)
        }

        let selectedCategory = categoryList.first(where: { $0.id == selectedCategoryId }) ?? allProductsCategory
        for i in categoryList.indices {
            categoryList[i].selected = (categoryList[i].id == selectedCategory.id)
        }
        currentCategory = selectedCategory
        categories = categoryList
        products = getVisibleProducts()

        if resetOrders {
            orders.removeAll()
            orderCounter = 0
            orders[0] = createOrder(0)
            currentOrderId = 0
        } else {
            trimOrdersToStockLimits()
        }
        return nil
    }

    func selectCategory(_ category: Category) {
        currentCategory = category
        categories = categories.map { cat in
            var c = cat
            c.selected = (cat.id == category.id)
            return c
        }
        updateVisibleProducts()
    }

    func addProduct(orderId: Int, product: ConfigProduct) {
        orders[orderId]?.addProduct(product)
    }

    func nextOrder() {
        let keys = orders.orderedKeys
        guard let idx = keys.firstIndex(of: currentOrderId) else { return }

        var nextId: Int?
        if idx + 1 < keys.count {
            nextId = keys[idx + 1]
        }
        if nextId == nil {
            orderCounter += 1
            nextId = orderCounter
            orders[nextId!] = createOrder(nextId!)
        }

        let currentOrder = orders[currentOrderId]
        if currentOrder?.isEmpty == true {
            orders.removeValue(forKey: currentOrderId)
        } else {
            currentOrder?.lastAddedProduct = nil
        }
        currentOrderId = nextId!
        updateVisibleProducts()
    }

    func previousOrder() {
        let keys = orders.orderedKeys
        guard let idx = keys.firstIndex(of: currentOrderId), idx > 0 else { return }
        let previousId = keys[idx - 1]
        let currentOrder = orders[currentOrderId]
        if currentOrder?.isEmpty == true {
            orders.removeValue(forKey: currentOrderId)
        } else {
            currentOrder?.lastAddedProduct = nil
        }
        currentOrderId = previousId
        updateVisibleProducts()
    }

    func hasPreviousOrder() -> Bool {
        guard let keys = orders.orderedKeys.first else { return false }
        return currentOrderId != keys
    }

    func hasNextOrder() -> Bool {
        guard let liveOrder = orders[currentOrderId] else { return false }
        return liveOrder.restartState == .enabled || currentOrderId != orders.orderedKeys.last
    }

    func deleteCurrentOrder() {
        let keys = orders.orderedKeys
        guard let idx = keys.firstIndex(of: currentOrderId) else { return }
        orders.removeValue(forKey: currentOrderId)
        let replacementId: Int
        if orders.isEmpty {
            orders[currentOrderId] = createOrder(currentOrderId)
            replacementId = currentOrderId
        } else if idx < keys.count - 1 {
            replacementId = keys[idx + 1]
        } else {
            replacementId = keys[max(0, idx - 1)]
        }
        currentOrderId = replacementId
        updateVisibleProducts()
    }

    func onOrderPaid(_ orderId: Int) {
        if currentOrderId == orderId {
            if hasPreviousOrder() {
                previousOrder()
            } else {
                nextOrder()
            }
        }
        orders.removeValue(forKey: orderId)
        updateVisibleProducts()
    }

    func canAddProduct(_ product: ConfigProduct) -> Bool {
        guard let stock = remainingStock(product) else { return true }
        return stock > 0
    }

    private func remainingStock(_ product: ConfigProduct) -> Int? {
        guard let stockLimit = productsById[product.id]?.stockLimit ?? product.stockLimit else { return nil }
        let reserved = orders.values.reduce(0) { total, liveOrder in
            total + (liveOrder.order.products.first(where: { $0.id == product.id })?.quantity ?? 0)
        }
        return max(stockLimit - reserved, 0)
    }

    private func isLegacyDefaultCategory(_ category: Category) -> Bool {
        category.name.caseInsensitiveCompare(legacyDefaultCategoryName) == .orderedSame
    }

    private func createOrder(_ orderId: Int) -> LiveOrder {
        LiveOrder(
            id: orderId,
            currency: currency,
            productsByCategory: productsByCategory,
            canAddProduct: { [weak self] product in
                self?.canAddProduct(product) ?? true
            },
            onChanged: { [weak self] in
                self?.updateVisibleProducts()
            }
        )
    }

    private func getVisibleProducts() -> [ConfigProduct] {
        guard let cat = currentCategory else { return [] }
        return (productsByCategory[cat] ?? []).map(decorateProduct)
    }

    private func updateVisibleProducts() {
        products = getVisibleProducts()
        objectWillChange.send()
    }

    private func decorateProduct(_ product: ConfigProduct) -> ConfigProduct {
        let remaining = remainingStock(product)
        var p = product
        p.availableToSell = !product.currencyMismatch && (remaining == nil || remaining! > 0)
        p.remainingStock = remaining
        return p
    }

    private func trimOrdersToStockLimits() {
        for liveOrder in orders.values {
            var modified = false
            let trimmedProducts: [ConfigProduct] = liveOrder.order.products.compactMap { orderProduct in
                guard let stockLimit = productsById[orderProduct.id]?.stockLimit else { return orderProduct }
                if orderProduct.quantity <= stockLimit { return orderProduct }
                modified = true
                if stockLimit <= 0 { return nil }
                var p = orderProduct
                p.quantity = stockLimit
                return p
            }
            if modified {
                liveOrder.order = Order(
                    id: liveOrder.order.id,
                    currency: liveOrder.order.currency,
                    availableCategories: liveOrder.order.availableCategories,
                    products: trimmedProducts
                )
                liveOrder.repairSelection()
            }
        }
    }
}

struct OrderedDictionary<Key: Hashable, Value> {
    private var dict: [Key: Value] = [:]
    private(set) var orderedKeys: [Key] = []

    var isEmpty: Bool { dict.isEmpty }
    var count: Int { dict.count }
    var values: [Value] { orderedKeys.compactMap { dict[$0] } }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            if let newValue {
                if dict[key] == nil {
                    orderedKeys.append(key)
                }
                dict[key] = newValue
            } else {
                dict.removeValue(forKey: key)
                orderedKeys.removeAll { $0 == key }
            }
        }
    }

    mutating func removeValue(forKey key: Key) {
        dict.removeValue(forKey: key)
        orderedKeys.removeAll { $0 == key }
    }

    mutating func removeAll() {
        dict.removeAll()
        orderedKeys.removeAll()
    }
}
