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

import SwiftUI


enum HistoryStatus {
    case unpaid
    case paid
    case paymentPending
    case paymentClaimed
    case refundPending
    case refunded

    var label: String {
        switch self {
        case .unpaid: return S.historyUnpaid
        case .paid: return S.historyPaid
        case .paymentPending: return S.historyPaymentPending
        case .paymentClaimed: return S.historyPaymentClaimed
        case .refundPending: return S.historyRefundPending
        case .refunded: return S.historyRefunded
        }
    }

    var backgroundColor: Color {
        switch self {
        case .unpaid: return .posErrorContainer
        case .paid: return .posPrimaryContainer
        case .paymentPending: return .posSecondaryContainer
        case .paymentClaimed: return .posTertiaryContainer
        case .refundPending: return .posSecondaryContainer
        case .refunded: return .posTertiaryContainer
        }
    }

    var foregroundColor: Color {
        switch self {
        case .unpaid: return .posOnErrorContainer
        case .paid: return .posOnPrimaryContainer
        case .paymentPending: return .posOnSecondaryContainer
        case .paymentClaimed: return .posOnTertiaryContainer
        case .refundPending: return .posOnSecondaryContainer
        case .refunded: return .posOnTertiaryContainer
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var refundManager: RefundManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var configManager: ConfigManager
    let onNavigate: (PosDestination) -> Void
    var openDrawer: (() -> Void)?
    @State private var showRefundStateMissing = false

    var body: some View {
        VStack(spacing: 0) {
            PosTopBar(title: S.menuHistory, onMenuTap: { openDrawer?() }) {
                Button(action: { historyManager.fetchHistory() }) {
                    Text(S.historyRefresh)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Color.posSecondaryContainer)
                        .foregroundColor(.posOnSecondaryContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }

            if historyManager.isLoading && historyManager.items.isEmpty {
                Spacer()
                ProgressView(S.configFetching)
                Spacer()
            } else if historyManager.items.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(S.historyLabel)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(historyManager.items.enumerated()), id: \.element.orderId) { index, item in
                            HistoryItemCard(
                                item: item,
                                hasPendingRefund: refundManager.pendingRefundOrderId == item.orderId,
                                activePayment: paymentManager.payment?.orderId == item.orderId ? paymentManager.payment : nil,
                                onRefundClicked: {
                                    refundManager.startRefund(item: item)
                                    onNavigate(.refund(item))
                                },
                                onDeleteClicked: {
                                    historyManager.deleteOrder(orderId: item.orderId)
                                },
                                onShowPaymentClicked: {
                                    paymentManager.resumePayment(item: item)
                                    onNavigate(.processPayment)
                                },
                                onShowRefundClicked: {
                                    if refundManager.resumeRefund(item: item) {
                                        onNavigate(.refundUri)
                                    } else {
                                        showRefundStateMissing = true
                                        historyManager.fetchHistory()
                                    }
                                }
                            )
                            .onAppear {
                                historyManager.loadMoreHistoryIfNeeded(lastVisibleIndex: index)
                            }
                        }

                        if historyManager.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("[HistoryView] onAppear items=\(historyManager.items.count) isLoading=\(historyManager.isLoading)")
            if configManager.merchantConfig?.baseUrl == nil {
                onNavigate(.config)
            } else {
                historyManager.fetchHistory()
            }
        }
        .alert(S.forceDeleteTitle, isPresented: .init(
            get: { historyManager.forceDeleteOrderId != nil },
            set: { if !$0 { historyManager.clearForceDeletePrompt() } }
        )) {
            Button(S.forceDeleteConfirm, role: .destructive) {
                if let orderId = historyManager.forceDeleteOrderId {
                    historyManager.forceDeleteOrder(orderId)
                }
            }
            Button(S.paymentCancel, role: .cancel) {
                historyManager.clearForceDeletePrompt()
            }
        } message: {
            Text(S.forceDeleteMessage)
        }
        .alert(S.errorHistory, isPresented: .init(
            get: { historyManager.errorMessage != nil },
            set: { if !$0 { historyManager.clearError() } }
        )) {
            Button(S.commonOk) { historyManager.clearError() }
        } message: {
            Text(historyManager.errorMessage ?? "")
        }
        .alert(S.commonError, isPresented: $showRefundStateMissing) {
            Button(S.commonOk) {}
        } message: {
            Text(S.refundStateMissing)
        }
    }
}

// MARK: - HistoryItemCard

struct HistoryItemCard: View {
    let item: OrderHistoryEntry
    let hasPendingRefund: Bool
    let activePayment: Payment?
    let onRefundClicked: () -> Void
    let onDeleteClicked: () -> Void
    let onShowPaymentClicked: () -> Void
    let onShowRefundClicked: () -> Void

    private var status: HistoryStatus {
        if item.hasPendingRefund { return .refundPending }
        if item.hasRefund { return .refunded }
        if hasPendingRefund { return .refundPending }
        if activePayment?.paid == true { return .paid }
        if activePayment?.claimed == true { return .paymentClaimed }
        if activePayment?.orderId == item.orderId && activePayment?.error == nil { return .paymentPending }
        if item.paid { return .paid }
        return .unpaid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.summary)
                        .font(.headline)
                    Text(item.amount.readableAmount)
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HistoryStatusBadge(status: status)

                    if item.hasPendingRefund, let pendingAmount = item.pendingRefundAmount, pendingAmount.isZero == false {
                        HistoryAmountBadge(amount: pendingAmount.readableAmount, status: status)
                    } else if item.hasRefund, let refundAmount = item.refundAmount {
                        HistoryAmountBadge(amount: refundAmount.readableAmount, status: status)
                    }
                }
            }

            Text(item.timestamp.date, style: .relative)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(S.historyRefNo(item.orderId))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if item.hasPendingRefund || hasPendingRefund {
                    Button(S.historyShowRefund, action: onShowRefundClicked)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else if item.refundable {
                    Button(S.historyRefund, action: onRefundClicked)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else if !item.paid {
                    Button(S.historyShowPayment, action: onShowPaymentClicked)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button(S.orderDelete, action: onDeleteClicked)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(Color.posSurface)
        .cornerRadius(12)
    }
}

struct HistoryStatusBadge: View {
    let status: HistoryStatus

    var body: some View {
        Text(status.label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .foregroundColor(status.foregroundColor)
            .cornerRadius(8)
    }
}

struct HistoryAmountBadge: View {
    let amount: String
    let status: HistoryStatus

    var body: some View {
        Text(amount)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .foregroundColor(status.foregroundColor)
            .cornerRadius(8)
    }
}
