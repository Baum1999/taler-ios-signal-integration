/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct AccountPicker: View {
    let title: String
    @Binding var value: Int
    let accountDetails: AccountDetailsArray
    let action: (Int) -> Void

    @State private var selected = 0

    var body: some View {
        Picker(title, selection: $selected) {
            ForEach(0..<accountDetails.count, id: \.self) { index in
                let detail = accountDetails[index]
                    if let amount = detail.transferAmount {
                        let amountStr = amount.formatted(specs: detail.currencySpecification,
                                                    isNegative: false,
                                                         scope: detail.scope,
                                                        useISO: false)
//            let _ = print(amountStr)
                        if let bankName = detail.bankLabel {
                            Text(bankName + ":   " + amountStr.0)
                                .accessibilityLabel(bankName + ":   " + amountStr.1)
                                .tag(index)
                        } else {
                            Text(amountStr.0)
                                .accessibilityLabel(amountStr.1)
                                .tag(index)
                        }
                    }
            }
        }
        .talerFont(.title3)
//        .pickerStyle(.menu)
        .onAppear() {
            withAnimation { selected = value }
        }
        .onChange(of: selected) { newValue in
            action(newValue)
        }
    }
}
