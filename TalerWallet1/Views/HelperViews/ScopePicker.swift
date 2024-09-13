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

    func label(balance: Balance) -> String {
        let label = balance.scopeInfo.url?.trimURL
                 ?? balance.scopeInfo.currency
        return String("\(label):\t\(formattedAmount(balance).nbs)")
    }

    var body: some View {
        HStack {
            Text("Use: ", comment: "ScopePicker")
            Spacer()
            if (balances.count > 0) {
                Picker(EMPTYSTRING, selection: $selected) {
                    ForEach(0..<balances.count, id: \.self) { index in
                        Text(label(balance: balances[index]))
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onAppear() {
                    withAnimation { selected = value }
                }
                .onChange(of: selected) { newValue in
                    action(newValue)
                }
            }
        }
        .padding(.leading)
        .talerFont(.title3)
    }
}
// MARK: -
//#Preview {
//    ScopePicker()
//}
