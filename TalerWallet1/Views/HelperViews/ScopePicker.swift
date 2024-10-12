/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct ScopePicker: View {
    @Binding var value: Int
    let balances: [Balance]
    let action: (Int) -> Void

    @State private var selected = 0

    func formattedAmount(_ balance: Balance) -> String {
        let amount = balance.available
        return amount.formatted(isNegative: false, useISO: false)
    }

    func row(_ balance: Balance) -> String {
        let urlOrCurrency = balance.scopeInfo.url?.trimURL
        ?? balance.scopeInfo.currency
        return String("\(urlOrCurrency):\t\(formattedAmount(balance).nbs)")
    }

    var body: some View {
        if (balances.count > 0) {
            Group {
                Picker(EMPTYSTRING, selection: $selected) {
                    ForEach(0..<balances.count, id: \.self) { index in
                        Text(row(balances[index]))
                            .tag(index)
                    }
                }
                .frame(width: .infinity)
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .onAppear() {
                withAnimation { selected = value }
            }
            .onChange(of: selected) { newValue in
                action(newValue)
            }
        }
    }
}
// MARK: -
//#Preview {
//    ScopePicker()
//}
