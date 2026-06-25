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

// MARK: - ProcessPaymentView

struct ProcessPaymentView: View {
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var configManager: ConfigManager
    let onNavigate: (PosDestination) -> Void

    @State private var showForceDeleteDialog = false
    @State private var errorTitle: String = ""
    @State private var errorDetail: String = ""
    @State private var showErrorAlert = false
    @Environment(\.dismiss) private var dismiss

    private var isTablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        paymentBody
            .navigationTitle(S.paymentProcessLabel)
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(paymentManager.$payment) { payment in
                guard let payment = payment else { return }
                handlePaymentChange(payment)
            }
            .onReceive(paymentManager.$deleteNeedsForce) { needsForce in
                handleDeleteNeedsForce(needsForce)
            }
            .alert(S.commonError, isPresented: $showErrorAlert) {
                Button(S.commonOk) { dismiss() }
            } message: {
                Text("\(errorTitle)\n\(errorDetail)")
            }
            .alert(S.forceDeleteTitle, isPresented: $showForceDeleteDialog) {
                Button(S.forceDeleteConfirm, role: .destructive) {
                    paymentManager.forceDeleteOrder()
                    dismiss()
                }
                Button(S.paymentCancel, role: .cancel) {
                    paymentManager.clearDeleteNeedsForce()
                }
            } message: {
                Text(S.forceDeleteMessage)
            }
    }

    @ViewBuilder
    private var paymentBody: some View {
        if let payment = paymentManager.payment {
            GeometryReader { geo in
                let leftWidth = geo.size.width * (isTablet ? 0.54 : 0.5)
                let rightWidth = geo.size.width * (isTablet ? 0.46 : 0.5)
                let qrSize = min(geo.size.width * (isTablet ? 0.45 : 0.4), geo.size.height * 0.7)
                HStack(spacing: 0) {
                    PaymentQRColumn(payment: payment, width: leftWidth, qrSize: qrSize, onShare: shareText)
                    Divider()
                    PaymentInfoColumn(payment: payment, displayDigits: configManager.currencySpec?.displayDigits ?? 2, width: rightWidth, onCancel: onCancelTapped)
                }
            }
        } else {
            ProgressView(S.configFetching)
        }
    }

    private func handlePaymentChange(_ payment: Payment) {
        if payment.paid { return }
        if let error = payment.error {
            let display = getPaymentErrorDisplay(payment: payment, error: error)
            errorTitle = display.0
            errorDetail = display.1
            showErrorAlert = true
        }
    }

    private func handleDeleteNeedsForce(_ needsForce: Bool?) {
        if needsForce == true {
            showForceDeleteDialog = true
        } else if needsForce == false {
            paymentManager.clearDeleteNeedsForce()
            dismiss()
        }
    }

    private func onCancelTapped() {
        if let payment = paymentManager.payment, payment.claimed {
            paymentManager.tryDeleteOrder()
        } else {
            paymentManager.cancelPayment()
            dismiss()
        }
    }

    private func getPaymentErrorDisplay(payment: Payment, error: String) -> (String, String) {
        if payment.orderId != nil {
            return (S.errorPayment, error)
        }
        let normalized = error.lowercased()
        if normalized.contains("inventory") || normalized.contains("stock") ||
           normalized.contains("insufficient") || normalized.contains("sold out") ||
           normalized.contains("out of stock") {
            return (S.errorInventoryUnavailable, error)
        }
        return (S.errorOrderCreation, error)
    }

    private func shareText(_ text: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
        }
        root.present(activityVC, animated: true)
    }
}

// MARK: - Payment Sub-views

private struct PaymentQRColumn: View {
    let payment: Payment
    let width: CGFloat
    let qrSize: CGFloat
    let onShare: (String) -> Void

    var body: some View {
        VStack {
            Spacer()
            qrContent
            Spacer()
            shareButtons
        }
        .frame(width: width)
    }

    @ViewBuilder
    private var qrContent: some View {
        if !payment.claimed {
            PosQRView(text: payment.talerPayUri, size: qrSize)
        }
    }

    @ViewBuilder
    private var shareButtons: some View {
        if !payment.claimed, let payUri = payment.talerPayUri {
            HStack(spacing: 12) {
                Button(S.paymentShareUri) { onShare(payUri) }
                    .buttonStyle(.bordered)
                Button(S.paymentCopyUri) { UIPasteboard.general.string = payUri }
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 12)
        }
    }
}

private struct PaymentInfoColumn: View {
    let payment: Payment
    var displayDigits: Int = 2
    let width: CGFloat
    let onCancel: () -> Void

    private var introText: String {
        if payment.claimed {
            return S.paymentClaimed
        } else if payment.talerPayUri != nil {
            return S.paymentIntro
        } else {
            return S.paymentFetchingLink
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(introText)
                .font(.title3)
                .multilineTextAlignment(.center)
            Text(payment.order.total.readableAmount(numDigits: displayDigits))
                .font(.title)
                .fontWeight(.bold)
            orderIdView
            Spacer()
            cancelButton
        }
        .padding()
        .frame(width: width)
    }

    @ViewBuilder
    private var orderIdView: some View {
        if let orderId = payment.orderId {
            Text(S.paymentOrderId(orderId))
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(S.paymentCancel)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.posError)
        .foregroundColor(.posOnError)
    }
}

// MARK: - PaymentSuccessView

struct PaymentSuccessView: View {
    let onNavigate: (PosDestination) -> Void
    @EnvironmentObject var paymentManager: PaymentManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let iconSize: CGFloat = min(geo.size.height * 0.22, 164.0)
            let buttonWidth: CGFloat = geo.size.width < 600 ? geo.size.width * 0.78 : geo.size.width * 0.6

            VStack(spacing: 0) {
                Spacer()
                successHero(iconSize: iconSize, height: geo.size.height)
                Spacer()
                continueButton(width: buttonWidth, height: geo.size.height)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .navigationTitle(S.paymentReceived)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func successHero(iconSize: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: max(height * 0.035, 12)) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.posPrimary)

            Text(S.paymentReceived)
                .font(height < 560 ? .title2 : height < 720 ? .title : .largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.posPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private func continueButton(width: CGFloat, height: CGFloat) -> some View {
        Button {
            let destination: PosDestination = paymentManager.payment?.origin == .amountEntry ? .amountEntry : .order
            paymentManager.reset()
            onNavigate(destination)
        } label: {
            Text(S.paymentBackButton)
                .fontWeight(.semibold)
                .frame(width: width)
                .padding(.vertical, max(height * 0.02, 14))
        }
        .buttonStyle(.borderedProminent)
        .padding(.bottom, max(height * 0.045, 16))
    }
}

