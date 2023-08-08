/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation


struct QRCodeDetailView: View {
    let talerURI: String
    let incoming: Bool
    let amount: Amount?

    var body: some View {
        if talerURI.count > 10 {
            VStack (alignment: .leading) {
                Text("Either copy and send this link:")
                    .multilineTextAlignment(.leading)
                    .font(.title3)
                    .padding(.vertical)

                Text(talerURI)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                    .padding(.bottom)

                CopyShare(textToCopy: talerURI)
                    .disabled(false)
                    .padding(.bottom)

                // TODO: use currency formatter instead of .readableDescription
                let amountStr = (amount == nil) ?
                    (incoming ? String(localized: "or let the payer scan this QR code to pay:")
                              : String(localized: "or let the payee scan this QR code to receive:"))
                :   (incoming ? String(localized: "or let the payer scan this QR code to pay \(amount!.readableDescription):",
                                       comment: "amount.readableDescription: 5,3 €")
                              : String(localized: "or let the payee scan this QR code to receive \(amount!.readableDescription):",
                                       comment: "amount.readableDescription: 7.41 $"))
                Text(amountStr)
                    .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
//                    .padding(.top, 30)
                    .font(.title3)
                HStack {
                    Spacer()
                    QRGeneratorView(text: talerURI)
                    Spacer()
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ContentView: View {
    @State var talerURI: String = "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520"

    var body: some View {
        List {
            QRCodeDetailView(talerURI: talerURI, incoming: false, amount: nil)
        }
    }
}
struct QRCodeDetailView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}
#endif
