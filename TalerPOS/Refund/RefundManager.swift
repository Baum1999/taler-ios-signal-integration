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

enum RefundResult: Equatable {
    case error(String)
    case pastDeadline
    case alreadyRefunded
    case success(refundUri: String, item: OrderHistoryEntry, amount: Amount, reason: String)

    static func == (lhs: RefundResult, rhs: RefundResult) -> Bool {
        switch (lhs, rhs) {
        case (.error(let a), .error(let b)): return a == b
        case (.pastDeadline, .pastDeadline): return true
        case (.alreadyRefunded, .alreadyRefunded): return true
        case (.success(let a1, let a2, let a3, let a4), .success(let b1, let b2, let b3, let b4)):
            return a1 == b1 && a2.orderId == b2.orderId && a3 == b3 && a4 == b4
        default: return false
        }
    }
}

@MainActor
class RefundManager: ObservableObject {
    @Published var toBeRefunded: OrderHistoryEntry?
    @Published var refundResult: RefundResult?
    @Published var pendingRefundOrderId: String?
    @Published var refundReceived = false

    private let api: MerchantApi
    private let configManager: ConfigManager
    private var statusTask: Task<Void, Never>?

    init(api: MerchantApi, configManager: ConfigManager) {
        self.api = api
        self.configManager = configManager
    }

    func startRefund(item: OrderHistoryEntry) {
        statusTask?.cancel()
        toBeRefunded = item
        refundResult = nil
        pendingRefundOrderId = nil
        refundReceived = false
    }

    func abortRefund() {
        statusTask?.cancel()
        toBeRefunded = nil
        refundResult = nil
        pendingRefundOrderId = nil
        refundReceived = false
    }

    func completeRefund() {
        statusTask?.cancel()
        toBeRefunded = nil
        refundResult = nil
        pendingRefundOrderId = nil
        refundReceived = false
    }

    func resumeRefund(item: OrderHistoryEntry) -> Bool {
        guard let current = refundResult,
              case .success(_, let successItem, _, _) = current,
              successItem.orderId == item.orderId else {
            return false
        }
        toBeRefunded = item
        pendingRefundOrderId = item.orderId
        if !refundReceived {
            observeRefundStatus(orderId: item.orderId)
        }
        return true
    }

    func refund(item: OrderHistoryEntry, amount: Amount, reason: String) {
        guard let merchantConfig = configManager.merchantConfig else { return }
        let request = RefundRequest(refund: amount, reason: reason)

        Task {
            do {
                let response = try await api.giveRefund(
                    merchantConfig: merchantConfig,
                    orderId: item.orderId,
                    request: request
                )
                self.refundResult = .success(
                    refundUri: response.talerRefundUri,
                    item: item,
                    amount: amount,
                    reason: reason
                )
                self.pendingRefundOrderId = item.orderId
                self.refundReceived = false
                self.observeRefundStatus(orderId: item.orderId)
            } catch {
                self.statusTask?.cancel()
                self.pendingRefundOrderId = nil
                self.refundReceived = false
                if let apiError = error as? ApiError, apiError.backendCode == 2602 {
                    self.refundResult = .alreadyRefunded
                } else {
                    self.refundResult = .error(error.localizedDescription)
                }
            }
        }
    }

    private func observeRefundStatus(orderId: String) {
        statusTask?.cancel()
        statusTask = Task {
            guard let merchantConfig = configManager.merchantConfig else { return }
            while !Task.isCancelled {
                do {
                    let response = try await api.checkOrder(merchantConfig: merchantConfig, orderId: orderId)
                    if case .paid(let refunded, let refundPending, let refundAmount) = response {
                        if refunded && !refundPending && refundAmount?.isZero == false {
                            self.refundReceived = true
                            break
                        }
                    }
                } catch {}
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}
