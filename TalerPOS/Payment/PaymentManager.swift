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

@MainActor
class PaymentManager: ObservableObject {
    @Published var payment: Payment?
    @Published var deleteNeedsForce: Bool?

    private let api: MerchantApi
    private let configManager: ConfigManager
    private var pollingTask: Task<Void, Never>?

    init(api: MerchantApi, configManager: ConfigManager) {
        self.api = api
        self.configManager = configManager
    }

    func createPayment(order: Order, includeProducts: Bool = true, origin: PaymentOrigin = .inventory) {
        guard let merchantConfig = configManager.merchantConfig else { return }

        payment = Payment(order: order, summary: order.summary, currency: order.currency, origin: origin)
        deleteNeedsForce = nil

        let inventoryProducts: [MinimalInventoryProduct]
        if includeProducts {
            inventoryProducts = order.products.compactMap { product -> MinimalInventoryProduct? in
                guard let pid = product.productId else { return nil }
                return MinimalInventoryProduct(productId: pid, quantity: product.quantity)
            }
        } else {
            inventoryProducts = []
        }
        let useInventoryProducts = includeProducts && !inventoryProducts.isEmpty

        let request = PostOrderRequest(
            order: order.toContractTerms(includeProducts: includeProducts && !useInventoryProducts),
            refundDelay: .hours(1),
            inventoryProducts: useInventoryProducts ? inventoryProducts : nil,
            createToken: true
        )

        Task {
            do {
                let response = try await api.postOrder(merchantConfig: merchantConfig, request: request)
                self.payment?.orderId = response.orderId
                self.startPolling(orderId: response.orderId)
            } catch {
                if let apiError = error as? ApiError, apiError.isInventoryError {
                    configManager.refreshInventory()
                }
                self.payment?.error = error.localizedDescription
            }
        }
    }

    func resumePayment(item: OrderHistoryEntry) {
        if let current = payment,
           current.orderId == item.orderId,
           !current.paid,
           current.error == nil {
            startPolling(orderId: item.orderId)
            return
        }

        let product = ConfigProduct(
            description: item.summary,
            price: item.amount,
            categories: [Int.min],
            quantity: 1
        )
        let order = Order(
            id: -2,
            currency: item.amount.currency,
            availableCategories: [:],
            products: [product]
        )
        payment = Payment(
            order: order,
            summary: item.summary,
            currency: item.amount.currency,
            origin: .inventory,
            orderId: item.orderId,
            paid: item.paid
        )
        if !item.paid {
            startPolling(orderId: item.orderId)
        }
    }

    func cancelPayment(error: String? = nil) {
        stopPolling()
        guard let merchantConfig = configManager.merchantConfig else {
            payment?.error = error
            return
        }
        if let payment = payment, !payment.paid, let orderId = payment.orderId {
            Task {
                try? await api.deleteOrder(merchantConfig: merchantConfig, orderId: orderId)
            }
        }
        payment?.error = error
    }

    func tryDeleteOrder() {
        stopPolling()
        guard let merchantConfig = configManager.merchantConfig,
              let orderId = payment?.orderId else { return }
        Task {
            do {
                try await api.deleteOrder(merchantConfig: merchantConfig, orderId: orderId)
                self.payment?.error = nil
                self.deleteNeedsForce = false
            } catch {
                self.deleteNeedsForce = true
            }
        }
    }

    func forceDeleteOrder() {
        guard let merchantConfig = configManager.merchantConfig,
              let orderId = payment?.orderId else { return }
        Task {
            do {
                try await api.deleteOrder(merchantConfig: merchantConfig, orderId: orderId, force: true)
                self.payment?.error = nil
                self.deleteNeedsForce = nil
            } catch {
                self.payment?.error = error.localizedDescription
            }
        }
    }

    func clearDeleteNeedsForce() {
        deleteNeedsForce = nil
    }

    func reset() {
        stopPolling()
        payment = nil
        deleteNeedsForce = nil
    }

    private func startPolling(orderId: String) {
        stopPolling()
        pollingTask = Task {
            guard let merchantConfig = configManager.merchantConfig else { return }
            var transientFailures = 0
            let maxTransientRetries = 10
            while !Task.isCancelled {
                do {
                    let response = try await api.checkOrder(merchantConfig: merchantConfig, orderId: orderId)
                    transientFailures = 0
                    switch response {
                    case .unpaid(let uri):
                        self.payment?.talerPayUri = uri
                    case .claimed:
                        self.payment?.claimed = true
                    case .paid(_, _, _):
                        self.payment?.paid = true
                        self.stopPolling()
                    }
                    if case .paid = response { break }
                } catch let apiError as ApiError where apiError.isUnauthorized {
                    self.configManager.forgetPassword()
                    self.configManager.sessionExpired = true
                    self.payment?.error = apiError.localizedDescription
                    break
                } catch let apiError as ApiError where apiError.isPermanentClientError {
                    self.payment?.error = apiError.localizedDescription
                    break
                } catch {
                    transientFailures += 1
                    if transientFailures >= maxTransientRetries {
                        self.payment?.error = error.localizedDescription
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
