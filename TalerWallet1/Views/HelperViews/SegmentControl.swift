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
    @ScaledMetric var frameHeight = 60       // relative to fontSize

    public var body: some View {
        let is26: Bool = if #available(iOS 26.0, *) { true } else { false }
        let cornerRadius: CGFloat = is26 ? 16.0 : 6.0
        let count = accountDetails.count
      if count > 0 {
        ZStack(alignment: .center) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .foregroundColor(WalletColors().pickerSelected(colorScheme, colorSchemeContrast))
                    .cornerRadius(cornerRadius)
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
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(WalletColors().sideBackgroundColor)
        )
      }
    } // body
}

struct SegmentControl2: View {
    @Binding var value: Int
    let strings: [String]
//    let action: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public var body: some View {
        let is26: Bool = if #available(iOS 26.0, *) { true } else { false }
        let cornerRadius: CGFloat = is26 ? 16.0 : 6.0
        let count = strings.count
        if count > 0 {
            ZStack(alignment: .center) {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .foregroundColor(WalletColors().pickerSelected(colorScheme, colorSchemeContrast))
                        .cornerRadius(cornerRadius)
                        .padding(4)
                        .frame(width: geo.size.width / CGFloat(count))
                        .offset(x: geo.size.width / CGFloat(count) * CGFloat(value), y: 0)
                }

                HStack(spacing: 0) {
                    ForEach((0..<count), id: \.self) { index in
                        let string = strings[index]
                        VStack(spacing: 6) {
                            Text(string)
                                .talerFont(.title3)
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
//                        .accessibilityLabel(a11yLabel)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(index == value ? .isSelected : [])
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
//                            action(index)
                            withAnimation(.easeInOut(duration: 0.150)) {
                                value = index
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(WalletColors().sideBackgroundColor)
            )
        }
    } // body
}
