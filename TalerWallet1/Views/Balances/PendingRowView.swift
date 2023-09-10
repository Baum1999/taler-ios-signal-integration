/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let amount: Amount
    let incoming: Bool

    var body: some View {
        HStack {
            let pendingColor = WalletColors().pendingColor(incoming)
            Image(systemName: incoming ? "text.badge.plus"
                                       : "text.badge.minus")
                .foregroundColor(pendingColor)
                .accessibilityFont(.largeTitle)
                .accessibility(hidden: true)

            Spacer()
            Text("pending\n" + (incoming ? "incoming" : "outgoing"))
                .accessibilityFont(.body)
            Spacer()
            VStack(alignment: .trailing) {
                let sign = incoming ? "+" : "-"
                let valueStr = sign + amount.valueStr
                Text(valueStr)
                    .foregroundColor(pendingColor)
                    .accessibilityFont(.title)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
// MARK: -
#if DEBUG
struct PendingRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            PendingRowView(amount: try! Amount(fromString: LONGCURRENCY + ":4.8"), incoming: true)
            PendingRowView(amount: try! Amount(fromString: LONGCURRENCY + ":3.25"), incoming: false)
        }
    }
}
#endif
