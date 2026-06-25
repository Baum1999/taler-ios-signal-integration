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

// MARK: - RefundFormView

struct RefundFormView: View {
    @EnvironmentObject var refundManager: RefundManager
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) private var dismiss
    let item: OrderHistoryEntry

    @State private var amountText: String = ""
    @State private var reason: String = ""
    @State private var errorText: String? = nil
    @State private var showErrorAlert: (String, String)? = nil
    @FocusState private var amountFocused: Bool
    @FocusState private var reasonFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.summary)
                .font(.body)

            TextField(S.refundAmount, text: $amountText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($amountFocused)
                .onSubmit { reasonFocused = true }
                .onChange(of: amountText) { _ in errorText = nil }

            if let errorText = errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.posError)
            }

            TextField(S.refundReason, text: $reason)
                .textFieldStyle(.roundedBorder)
                .focused($reasonFocused)
                .onSubmit { submitRefund() }

            Button(action: submitRefund) {
                Text(S.refundConfirm)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: {
                refundManager.abortRefund()
                dismiss()
            }) {
                Text(S.paymentCancel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(20)
        .contentShape(Rectangle())
        .onTapGesture {
            amountFocused = false
            reasonFocused = false
        }
        .navigationTitle(S.historyRefund)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            amountText = item.amount.amountStr(numDigits: configManager.currencySpec?.inputDigits ?? 2)
            amountFocused = true
        }
        .onChange(of: refundManager.refundResult) { result in
            guard let result = result else { return }
            switch result {
            case .error(let msg):
                showErrorAlert = (S.historyRefund, msg)
            case .pastDeadline:
                showErrorAlert = (S.historyRefund, S.refundErrorDeadline)
            case .alreadyRefunded:
                showErrorAlert = (S.historyRefund, S.refundErrorAlreadyRefunded)
            case .success:
                break
            }
        }
        .alert(S.commonError, isPresented: .init(
            get: { showErrorAlert != nil },
            set: { if !$0 { showErrorAlert = nil } }
        )) {
            Button(S.commonOk) { showErrorAlert = nil }
        } message: {
            if let err = showErrorAlert {
                Text("\(err.0): \(err.1)")
            }
        }
    }

    private func submitRefund() {
        amountFocused = false
        reasonFocused = false

        let maxAmount = item.amount
        let normalizedText = amountText.trimmingCharacters(in: .whitespaces)

        let inputAmount: Amount
        if normalizedText.isEmpty {
            inputAmount = maxAmount
        } else {
            guard let parsed = Amount.fromString(item.amount.currency, normalizedText) else {
                errorText = S.refundErrorInvalidAmount
                return
            }
            inputAmount = parsed
        }

        if inputAmount > maxAmount {
            errorText = S.refundErrorMaxAmount(maxAmount.amountStr(numDigits: configManager.currencySpec?.inputDigits ?? 2))
            return
        }
        if inputAmount.isZero {
            errorText = S.refundErrorZero
            return
        }

        refundManager.refund(item: item, amount: inputAmount, reason: reason)
    }
}

// MARK: - RefundUriView

struct RefundUriView: View {
    @EnvironmentObject var refundManager: RefundManager
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) private var dismiss

    private var isTablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if case .success(let refundUri, let item, let amount, let reason) = refundManager.refundResult {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        VStack {
                            Spacer()
                            let qrSize = min(geo.size.width * (isTablet ? 0.45 : 0.4), geo.size.height * 0.7)
                            PosQRView(text: refundUri, size: qrSize)
                            Spacer()
                        }
                        .frame(width: geo.size.width * (isTablet ? 0.54 : 0.5))

                        Divider()

                        VStack(spacing: 16) {
                            Spacer()

                            Text(S.refundIntro)
                                .font(.title3)
                                .multilineTextAlignment(.center)

                            Text(amount.readableAmount(numDigits: configManager.currencySpec?.displayDigits ?? 2))
                                .font(.title)
                                .fontWeight(.bold)

                            Text(S.paymentOrderId(item.orderId) + "\n" + S.refundReason + ": " + reason)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Spacer()

                            Button(action: {
                                refundManager.abortRefund()
                                dismiss()
                            }) {
                                Text(S.refundAbort)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.posError)
                            .foregroundColor(.posOnError)
                        }
                        .padding()
                        .frame(width: geo.size.width * (isTablet ? 0.46 : 0.5))
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text(S.refundStateMissing)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .onAppear { dismiss() }
            }
        }
        .navigationTitle(S.historyRefund)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: refundManager.refundReceived) { received in
            if received {
                refundManager.completeRefund()
            }
        }
    }
}
