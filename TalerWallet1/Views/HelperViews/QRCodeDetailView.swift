/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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

    var body: some View {
        if talerURI.count > 10 {
            Section {
                let eitherMini = incoming ? String(localized: "Either (payer) Mini 1",
                                                defaultValue: "Either",
                                                     comment: "Either (copy/share this link to the payer)")
                                          : String(localized: "Either (payee) Mini 1",
                                                defaultValue: "Either",
                                                     comment: "Either (copy/share this link to the payee)")
                let eitherLong = incoming ? String(localized: "Either (payer) Long 1",
                                                defaultValue: "Either provide this payment link")
                                          : String(localized: "Either (payee) Long 1",
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

                let otherPartyMini = incoming ? String(localized: "Either (payer) Mini 2", defaultValue: "or scan this")
                                              : String(localized: "Either (payee) Mini 2", defaultValue: "or scan this")
                let otherPartyLong = incoming ? String(localized: "Either (payer) Long 2", defaultValue: "to the payer, or")
                                              : String(localized: "Either (payee) Long 2", defaultValue: "to the payee, or")
                Text(minimalistic ? otherPartyMini : otherPartyLong)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                Group {
                    if #available(iOS 16.0, *) {
                        let screenWidth = UIScreen.screenWidth
                        GradientBorder(size: screenWidth/1.8,
                                      color: .accentColor,
                                 background: WalletColors().backgroundColor) {
                            QRGeneratorView(text: talerURI)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        QRGeneratorView(text: talerURI)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                    .accessibilityLabel("QR Code")
                    .listRowSeparator(.hidden)

                let amountStr = amount.formatted(isNegative: false)
                let scanMini = incoming ? String(localized: "Either (payer) Mini 3",
                                              defaultValue: "to pay \(amountStr).", comment: "e.g. '5,3 €'")
                                        : String(localized: "Either (payee) Mini 3",
                                              defaultValue: "to receive \(amountStr).", comment: "e.g. '$ 7.41'")
                let scanLong = incoming ? String(localized: "Either (payer) Long 3",
                                              defaultValue: "let the payer scan this QR code to pay \(amountStr).",
                                                   comment: "e.g. '5,3 €'")
                                        : String(localized: "Either (payee) Long 3",
                                              defaultValue: "let the payee scan this QR code to receive \(amountStr).",
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
