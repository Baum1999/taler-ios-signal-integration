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
            Image(systemName: incoming ? "text.badge.plus"
                                       : "text.badge.minus")
                .font(.largeTitle)
//                .foregroundColor(WalletColors().pendingColor)    // pending is always gray
                .foregroundColor(WalletColors().pendingColor(incoming))
                .accessibility(hidden: true)

            Spacer()
            Text("pending\n" + (incoming ? "incoming" : "outgoing"))
            Spacer()
            VStack(alignment: .trailing) {
                let sign = incoming ? "+" : "-"
                Text(sign + "\(amount.valueStr)")
                    .font(.title)
                    .foregroundColor(WalletColors().pendingColor(incoming))
//                Text("PENDING")
//                    .font(.callout)
//                    .foregroundColor(WalletColors().pendingColor(incoming))
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
