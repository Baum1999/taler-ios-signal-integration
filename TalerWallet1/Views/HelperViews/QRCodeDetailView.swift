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
    let amount: Amount

    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var amountStr: String {
        if let currencyInfo = controller.info(for: amount.currencyStr) {
            return amount.string(currencyInfo)
        }
        return amount.readableDescription
    }

    var body: some View {
        if talerURI.count > 10 {
            Section {
                let eitherMini = incoming ? String(localized: "Either (payer)", defaultValue: "Either",
                                                     comment: "Either (copy/share this link to the payer)")
                                          : String(localized: "Either (payee)", defaultValue: "Either",
                                                     comment: "Either (copy/share this link to the payee)")
                let eitherLong = incoming ? String(localized: "Either provide this payment link (payer)",
                                                defaultValue: "Either provide this payment link")
                                          : String(localized: "Either provide this payment link (payee)",
                                                defaultValue: "Either provide this payment link")
                Text(minimalistic ? eitherMini : eitherLong)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
//                    .padding(.vertical)
                    .listRowSeparator(.hidden)
                CopyShare(textToCopy: talerURI)
                    .disabled(false)
//                    .padding(.bottom)
                    .listRowSeparator(.hidden)

                let otherPartyMini = incoming ? String(localized: "or scan this(payer)", defaultValue: "or scan this")
                                              : String(localized: "or scan this(payee)", defaultValue: "or scan this")
                let otherPartyLong = incoming ? String(localized: "to the payer, or")
                                              : String(localized: "to the payee, or")
                Text(minimalistic ? otherPartyMini : otherPartyLong)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                QRGeneratorView(text: talerURI)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("QR Code")
                    .listRowSeparator(.hidden)

                let scanMini = incoming ? String(localized: "to pay \(amountStr).", comment: "e.g. '5,3 €'")
                                        : String(localized: "to receive \(amountStr).", comment: "e.g. '$ 7.41'")
                let scanLong = incoming ? String(localized: "let the payer scan this QR code to pay \(amountStr).",
                                                   comment: "e.g. '5,3 €'")
                                        : String(localized: "let the payee scan this QR code to receive \(amountStr).",
                                                   comment: "e.g. '$ 7.41'")
                Text(minimalistic ? scanMini : scanLong)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
            }
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ContentView: View {
    @State var talerURI: String = "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520"

    var body: some View {
        let amount = Amount(currency: LONGCURRENCY, cent: 123)
        List {
            QRCodeDetailView(talerURI: talerURI, incoming: false, amount: amount)
        }
    }
}
struct QRCodeDetailView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}
#endif
