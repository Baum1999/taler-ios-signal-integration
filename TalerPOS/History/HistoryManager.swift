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
import os

private let logger = Logger(subsystem: "net.taler.pos", category: "HistoryManager")
private let pageSize = 20
private let loadMoreThreshold = 5

@MainActor
class HistoryManager: ObservableObject {
    @Published var items: [OrderHistoryEntry] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var forceDeleteOrderId: String?

    private let api: MerchantApi
    private let configManager: ConfigManager
    private var loadedItems: [OrderHistoryEntry] = []
    private var nextOffset: Int64?
    private var reachedEnd = false

    init(api: MerchantApi, configManager: ConfigManager) {
        self.api = api
        self.configManager = configManager
    }

    func fetchHistory() {
        if ScreenshotController.isActive { return }
        fetchHistoryPage(reset: true)
    }

    func loadMoreHistoryIfNeeded(lastVisibleIndex: Int) {
        guard !isLoading, !isLoadingMore, !reachedEnd else { return }
        if items.isEmpty { return }
        if lastVisibleIndex < items.count - 1 - loadMoreThreshold { return }
        fetchHistoryPage(reset: false)
    }

    func deleteOrder(orderId: String) {
        guard let merchantConfig = configManager.merchantConfig else { return }
        isLoading = true
        Task {
            do {
                try await api.deleteOrder(merchantConfig: merchantConfig, orderId: orderId)
                self.configManager.refreshInventory()
                self.fetchHistory()
            } catch {
                self.isLoading = false
                self.forceDeleteOrderId = orderId
            }
        }
    }

    func forceDeleteOrder(_ orderId: String) {
        forceDeleteOrderId = nil
        isLoading = true
        guard let merchantConfig = configManager.merchantConfig else { return }
        Task {
            do {
                try await api.deleteOrder(merchantConfig: merchantConfig, orderId: orderId, force: true)
                self.configManager.refreshInventory()
                self.fetchHistory()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func clearForceDeletePrompt() {
        forceDeleteOrderId = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func fetchHistoryPage(reset: Bool) {
        if ScreenshotController.isActive { return }
        guard let merchantConfig = configManager.merchantConfig else {
            logger.error("fetchHistoryPage: no merchantConfig, bailing")
            isLoading = false
            isLoadingMore = false
            return
        }
        if reset {
            isLoading = true
            isLoadingMore = false
        } else {
            isLoadingMore = true
        }

        let offset = reset ? nil : nextOffset
        Task {
            do {
                logger.warning("Fetching history reset=\(reset) offset=\(String(describing: offset))")
                let history = try await api.getOrderHistory(
                    merchantConfig: merchantConfig,
                    limit: -pageSize,
                    offset: offset
                )
                logger.warning("Got \(history.orders.count) orders")
                self.isLoading = false
                self.isLoadingMore = false

                if reset {
                    self.loadedItems.removeAll()
                    self.reachedEnd = false
                }

                let existingIds = Set(self.loadedItems.map(\.orderId))
                let newItems = history.orders.filter { !existingIds.contains($0.orderId) }

                if !newItems.isEmpty {
                    self.loadedItems += newItems
                    self.nextOffset = newItems.last?.rowId ?? self.loadedItems.last?.rowId
                }
                if history.orders.count < pageSize || newItems.isEmpty {
                    self.reachedEnd = true
                }
                self.items = self.loadedItems
                logger.warning("Total items: \(self.items.count)")

                await enrichOrders(newItems: newItems, merchantConfig: merchantConfig)
            } catch {
                logger.error("History fetch failed: \(error)")
                self.isLoading = false
                self.isLoadingMore = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func enrichOrders(newItems: [OrderHistoryEntry], merchantConfig: MerchantConfig) async {
        for item in newItems where item.paid {
            do {
                let response = try await api.checkOrder(merchantConfig: merchantConfig, orderId: item.orderId)
                if case .paid(let refunded, let refundPending, let refundAmount) = response {
                    if let idx = self.loadedItems.firstIndex(where: { $0.orderId == item.orderId }) {
                        self.loadedItems[idx].refunded = refunded
                        self.loadedItems[idx].refundPending = refundPending
                        if let ra = refundAmount {
                            self.loadedItems[idx].refundAmount = ra
                        }
                        self.items = self.loadedItems
                    }
                }
            } catch {
                continue
            }
        }
    }
}
