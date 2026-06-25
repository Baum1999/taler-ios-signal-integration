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

private let quickAmountProductId = "quick_amount"

struct AmountEntryView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var orderManager: OrderManager
    let onNavigate: (PosDestination) -> Void
    var openDrawer: (() -> Void)?

    @State private var amount: Amount = .zero("")
    @State private var selectedCurrency: String = ""
    @State private var errorMessage: String?

    private var numInputDigits: Int {
        configManager.currencySpec?.numFractionalInputDigits ?? 2
    }

    private var isTablet: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var amountText: String {
        amount.amountStr(numDigits: numInputDigits)
    }

    var body: some View {
        VStack(spacing: 0) {
            PosTopBar(title: S.menuAmountEntry, onMenuTap: { openDrawer?() })

            if isTablet {
                tabletLayout
            } else {
                phoneLayout
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let currency = configManager.currency {
                selectedCurrency = currency
                amount = .zero(currency)
            }
        }
    }

    // MARK: - Phone: horizontal Row (amount 32% | keypad 68%)

    private var phoneLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 8) {
                phoneAmountPane
                    .frame(width: geo.size.width * 0.32)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                keypadPane(isCompact: geo.size.height <= 540)
                    .frame(width: geo.size.width * 0.68 - 16)
                    .padding(4)
            }
            .padding(8)
        }
    }

    // MARK: - Tablet: vertical Column (amount 35% | keypad 65% at 60% width)

    private var tabletLayout: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                tabletAmountPane
                    .frame(height: geo.size.height * 0.35)

                HStack {
                    Spacer()
                    keypadPane(isCompact: false)
                        .frame(width: geo.size.width * 0.6)
                    Spacer()
                }
                .frame(height: geo.size.height * 0.65 - 12)
            }
            .padding(16)
        }
    }

    // MARK: - Phone Amount Pane (vertical: amount text, currency dropdown)

    private var phoneAmountPane: some View {
        VStack(spacing: 12) {
            phoneAmountText

            currencyDropdown

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.posError)
            }
        }
    }

    private var phoneAmountText: some View {
        let text = amountText
        let len = text.count
        let fontSize: CGFloat = {
            if len <= 6 { return 56 }
            if len <= 8 { return 48 }
            if len <= 10 { return 40 }
            if len <= 12 { return 32 }
            if len <= 14 { return 26 }
            return 22
        }()
        return Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .default))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Tablet Amount Pane (horizontal: amount text + currency dropdown)

    private var tabletAmountPane: some View {
        HStack(spacing: 12) {
            Spacer()

            Text(amountText)
                .font(.system(size: 56, weight: .bold, design: .default))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            currencyDropdown

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Currency Dropdown (OutlinedTextField-style)

    private var currencyDropdown: some View {
        Menu {
            if let currency = configManager.currency {
                Button(currency) {
                    selectCurrency(currency)
                }
            }
        } label: {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(S.amountEntryLabel)
                        .font(.caption)
                        .foregroundColor(.posOnSurfaceVariant)
                    Text(selectedCurrency.isEmpty ? "---" : selectedCurrency)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.posOnSurface)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.posOnSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 96)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.posSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.posOutlineVariant, lineWidth: 1)
            )
        }
    }

    private func selectCurrency(_ currency: String) {
        if selectedCurrency != currency {
            selectedCurrency = currency
            amount = .zero(currency)
            errorMessage = nil
        }
    }

    // MARK: - Keypad Pane

    private func keypadPane(isCompact: Bool) -> some View {
        let rowSpacing: CGFloat = isCompact ? 6 : 8
        let digitFontSize: CGFloat = isCompact ? 24 : 28

        return VStack(spacing: rowSpacing) {
            ForEach(digitRows, id: \.self) { row in
                HStack(spacing: rowSpacing) {
                    ForEach(row, id: \.self) { digit in
                        AmountKeyButton(
                            text: digit,
                            fontSize: digitFontSize,
                            action: { handleKey(digit) }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            }

            bottomRow(rowSpacing: rowSpacing, digitFontSize: digitFontSize, isCompact: isCompact)
                .frame(maxHeight: .infinity)

            chargeButton
        }
    }

    private var digitRows: [[String]] {
        [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
        ]
    }

    private func bottomRow(rowSpacing: CGFloat, digitFontSize: CGFloat, isCompact: Bool) -> some View {
        let clearLabel = S.amountEntryClear
        let clearFontSize: CGFloat = {
            let len = clearLabel.count
            if len >= 14 { return isCompact ? 12 : 14 }
            if len >= 10 { return isCompact ? 14 : 16 }
            return isCompact ? 16 : 20
        }()

        return HStack(spacing: rowSpacing) {
            AmountKeyButton(
                text: clearLabel,
                fontSize: clearFontSize,
                action: { handleKey("clear") }
            )

            AmountKeyButton(
                text: "0",
                fontSize: digitFontSize,
                action: { handleKey("0") }
            )

            Button(action: { handleKey("backspace") }) {
                Image(systemName: "delete.backward")
                    .font(.system(size: digitFontSize))
                    .foregroundColor(.posOnSecondaryContainer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.posSecondaryContainer)
                    .cornerRadius(12)
            }
            .accessibilityLabel(S.amountEntryBackspace)
        }
    }

    private var chargeButton: some View {
        let canCharge = !amount.isZero && !selectedCurrency.isEmpty
        return Button(action: createPayment) {
            Text(S.amountEntryCreateOrder)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canCharge ? Color.posPrimary : Color.posSecondary.opacity(0.12))
                .foregroundColor(canCharge ? .posOnPrimary : .posOnSurface.opacity(0.38))
                .cornerRadius(12)
        }
        .disabled(!canCharge)
    }

    // MARK: - Input

    private func handleKey(_ key: String) {
        errorMessage = nil
        let currency = selectedCurrency.isEmpty ? (configManager.currency ?? "") : selectedCurrency
        if amount.currency != currency {
            amount = .zero(currency)
        }
        switch key {
        case "clear":
            amount = .zero(currency)
        case "backspace":
            amount = amount.removeInputDigit(numInputDigits: numInputDigits)
        default:
            if let digit = Int(key) {
                if let newAmount = amount.addInputDigit(digit, numInputDigits: numInputDigits) {
                    amount = newAmount
                }
            }
        }
    }

    // MARK: - Create Payment

    private func createPayment() {
        guard !amount.isZero else {
            errorMessage = S.amountEntryErrorZero
            return
        }
        guard let configuredCurrency = configManager.currency else {
            onNavigate(.config)
            return
        }
        if selectedCurrency != configuredCurrency {
            errorMessage = S.amountEntryErrorWrongCurrency
            return
        }

        let product = ConfigProduct(
            productId: quickAmountProductId,
            description: S.amountEntryProductDescription,
            price: amount,
            categories: [Int.min],
            quantity: 1
        )
        let order = Order(
            id: -1,
            currency: configuredCurrency,
            availableCategories: [:],
            products: [product]
        )
        paymentManager.createPayment(order: order, includeProducts: false, origin: .amountEntry)
        onNavigate(.processPayment)
    }
}

// MARK: - Key Button

private struct AmountKeyButton: View {
    let text: String
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 2)
                .background(Color.posSecondaryContainer)
                .foregroundColor(.posOnSecondaryContainer)
                .cornerRadius(12)
        }
    }
}
