/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct BalanceRowButtons: View {
    let amount: Amount
    let narrow: Bool
    let lineLimit: Int
    let sendAction: () -> Void
    let recvAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        let currency = amount.currencyStr
        Group {
            Button("Request\nPayment", action: recvAction)
                .lineLimit(lineLimit)
                .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: narrow, aligned: .center))
            Button("Send\n\(currency)", action: sendAction)
                .lineLimit(lineLimit)
                .disabled(amount.isZero)
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: narrow, aligned: .center))

        }
    }
}

struct BalanceRowButtons_Previews: PreviewProvider {
    static var previews: some View {
        List {
            VStack {
                let amount = try! Amount(fromString: LONGCURRENCY + ":1234.56")
                BalanceRowButtons(amount: Amount(currency: "TestKUDOS", value: 1234),
                                  narrow: false, lineLimit: 0,
                                  sendAction: {}, recvAction: {})
                BalanceButton(amount: amount, rowAction: {})
            }
            HStack {
                let amount = try! Amount(fromString: "KUDOS" + ":1234.56")
                BalanceRowButtons(amount: amount,
                                  narrow: true, lineLimit: 2,
                                  sendAction: {}, recvAction: {})
                BalanceButton(amount: amount, rowAction: {})
            }
        }
    }
}
