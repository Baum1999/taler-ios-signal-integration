/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

/// This view shows the currency row in a currency section
/// [Send Coins]  [Receive Coins]     Balance

struct BalanceRowView: View {
    let amount: Amount
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    var body: some View {
        HStack {
            Button("Request\nPayment", action: recvAction)
                .lineLimit(2)
                .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .leading))
            Button("Send\nCoins", action: sendAction)
                .lineLimit(2)
                .disabled(amount.isZero)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .leading))
            Button(action: rowAction) {
                VStack(alignment: .trailing) {
                    Text("Balance")
                        .font(.footnote)
                        .accessibility(sortPriority: 2)
                    Text("\(amount.valueStr)")  // TODO: CurrencyFormatter
                        .font(.title)
                        .accessibility(sortPriority: 1)
                }
            }   .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .plain, aligned: .trailing))
        }
        .fixedSize(horizontal: false, vertical: true)   // should make all buttons equal height - but doesn't
        .accessibilityElement(children: .combine)
    }
}
// MARK: -
#if DEBUG
struct BalanceRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            BalanceRowView(amount: try! Amount(fromString: LONGCURRENCY + ":0.1"),
                           sendAction: {}, recvAction: {}, rowAction: {})
        }
    }
}
#endif
