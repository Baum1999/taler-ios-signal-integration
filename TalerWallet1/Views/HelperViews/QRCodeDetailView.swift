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
            Section {
                Text("Either", comment: "Either (copy/share)")
                    .multilineTextAlignment(.leading)
                    .accessibilityFont(.title3)
//                    .padding(.vertical)
                    .listRowSeparator(.hidden)

                CopyShare(textToCopy: talerURI)
                    .disabled(false)
//                    .padding(.bottom)
                    .listRowSeparator(.hidden)

                let otherParty = incoming ? String(localized: "payer", comment: "the payment link to the (otherParty), or")
                                          : String(localized: "payee", comment: "the payment link to the (otherParty), or")
                Text("the payment link to the \(otherParty), or", comment:  "...the payment link to the (payer/payee), or")
                    .multilineTextAlignment(.leading)
                    .accessibilityFont(.title3)
                    .listRowSeparator(.hidden)

                HStack {
                    Spacer()
                    QRGeneratorView(text: talerURI)
                        .accessibilityLabel("QR Code")
                    Spacer()
                }
                .listRowSeparator(.hidden)

                // TODO: use currency formatter instead of .readableDescription
                let hintStr = (amount == nil) ?
                    (incoming ? String(localized: "let the payer scan this QR code to pay.")
                              : String(localized: "let the payee scan this QR code to receive."))
                :   (incoming ? String(localized: "let the payer scan this QR code to pay \(amount!.readableDescription).",
                                       comment: "e.g. '5,3 €'")
                              : String(localized: "let the payee scan this QR code to receive \(amount!.readableDescription).",
                                       comment: "e.g. '$ 7.41'"))
                Text(hintStr)
                    .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                    .accessibilityFont(.title3)
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
