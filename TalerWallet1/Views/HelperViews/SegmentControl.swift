/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct SegmentControl: View {
    @Binding var value: Int
    let accountDetails: [ExchangeAccountDetails]
    let action: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var selectedAccount = 0
    @ScaledMetric var frameHeight = 80       // relative to fontSize

    public var body: some View {
        let count = accountDetails.count
        ZStack(alignment: .center) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6.0)
                    .foregroundColor(WalletColors().pickerSelected(colorScheme, colorSchemeContrast))
                    .cornerRadius(6.0)
                    .padding(4)
                    .frame(width: geo.size.width / CGFloat(count))
                    .offset(x: geo.size.width / CGFloat(count) * CGFloat(selectedAccount), y: 0)
            }
            .frame(height: frameHeight)

            HStack(spacing: 0) {
                ForEach((0..<count), id: \.self) { index in
                    let detail = accountDetails[index]
                    let specs = detail.currencySpecification
                    let scope = detail.scope
                    let amount = detail.transferAmount
                    let formatted = amount?.formatted(specs: specs,
                                                 isNegative: false,
                                                      scope: scope,
                                                     useISO: false)
                                    ?? (EMPTYSTRING, EMPTYSTRING)
                    let bankName = detail.bankLabel
                    let a11yLabel = bankName != nil ? (bankName! + SPACE + formatted.1)
                                                    : formatted.1
//            let _ = print(amountStr)
                    VStack(spacing: 6) {
                        Text(formatted.0)
                            .talerFont(.title3)
                        if let bankName {
                            Text(bankName)
                                .talerFont(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(a11yLabel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(index == selectedAccount ? .isSelected : [])
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.150)) {
                            selectedAccount = index
                        }
                    }
                }
            }
        }
        .onAppear() {
            if selectedAccount != value {
                withAnimation { selectedAccount = value }
            }
        }
        .onChange(of: selectedAccount) { selected in
            action(selected)
        }
        .background(
            RoundedRectangle(cornerRadius: 6.0)
                .fill(WalletColors().sideBackgroundColor)
        )
    }
}
