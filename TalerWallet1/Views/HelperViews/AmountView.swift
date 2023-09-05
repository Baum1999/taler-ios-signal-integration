/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct AmountView: View {
    let title: String
    let value: String
    let color: Color
    let large: Bool      // set to false for QR or IBAN

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                .multilineTextAlignment(.leading)
                .font(.talerBody)
            HStack {
                Spacer()
                Text(value)
                    .fixedSize(horizontal: false, vertical: true)   // wrap in scrollview
                    .multilineTextAlignment(.center)
                    .font(large ? .talerTitle : .talerTitle2)
//                    .fontWeight(large ? .medium : .regular)       // @available(iOS 16.0, *)
                    .foregroundColor(color)
                    .monospacedDigit()
                Spacer()
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)
    }
}

struct AmountView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            AmountView(title: "Fee", value: "- 0,2 Taler",
                       color: Color("Outgoing"), large: true)
            AmountView(title: "Coins", value: "4,8 Taler",
                       color: Color("Incoming"), large: false)
        }
    }
}
