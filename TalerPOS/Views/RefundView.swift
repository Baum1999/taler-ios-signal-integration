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

    @State private var amount: Amount = .zero("")
    @State private var reason: String = ""
    @State private var errorText: String? = nil
    @State private var showErrorAlert: (String, String)? = nil
    @FocusState private var reasonFocused: Bool

    private var numInputDigits: Int {
        configManager.currencySpec?.numFractionalInputDigits ?? 2
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 12) {
                    Text(item.summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(S.refundReason)
                            .font(.caption)
                            .foregroundColor(.posOnSurfaceVariant)
                        TextField(S.refundReason, text: $reason)
                            .focused($reasonFocused)
                            .submitLabel(.done)
                            .onSubmit { reasonFocused = false }
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.posOutline, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)

                    HStack {
                        Spacer()
                        Text(amount.amountStr(numDigits: numInputDigits))
                            .font(.system(size: 40, weight: .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(item.amount.currency)
                            .font(.title3)
                            .foregroundColor(.posOnSurfaceVariant)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .onTapGesture { reasonFocused = false }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(.posError)
                    }

                    AmountNumpad(
                        amount: $amount,
                        currency: item.amount.currency,
                        numInputDigits: numInputDigits,
                        isCompact: true,
                        onKeyPressed: {
                            reasonFocused = false
                            errorText = nil
                        }
                    )
                    .frame(height: geo.size.height * 0.45)
                    .padding(.horizontal, 20)

                    Button(action: submitRefund) {
                        Text(S.refundConfirm)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(!amount.isZero ? Color.posPrimary : Color.posSurfaceVariant)
                            .foregroundColor(!amount.isZero ? .posOnPrimary : .posOnSurfaceVariant)
                            .cornerRadius(12)
                    }
                    .disabled(amount.isZero)
                    .padding(.horizontal, 20)

                    Button(action: {
                        refundManager.abortRefund()
                        dismiss()
                    }) {
                        Text(S.paymentCancel)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.posErrorContainer)
                            .foregroundColor(.posOnErrorContainer)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(S.historyRefund)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            amount = item.amount
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
        reasonFocused = false
        let maxAmount = item.amount

        if amount > maxAmount {
            errorText = S.refundErrorMaxAmount(maxAmount.amountStr(numDigits: numInputDigits))
            return
        }
        if amount.isZero {
            errorText = S.refundErrorZero
            return
        }

        refundManager.refund(item: item, amount: amount, reason: reason)
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
