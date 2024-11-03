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
    let talerCopyShare: String
    let incoming: Bool
    let amount: Amount
    let specs: CurrencySpecification

    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        if talerURI.count > 10 {
            Section {
                Group {
//                    if #available(iOS 16.0, *) {
//                        let screenWidth = UIScreen.screenWidth
//                        GradientBorder(size: screenWidth/1.8,
//                                      color: .accentColor,
//                                 background: WalletColors().backgroundColor) {
//                            QRGeneratorView(text: talerURI)
//                                .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                    } else {
                        QRGeneratorView(text: talerURI)
                            .frame(maxWidth: .infinity, alignment: .center)
//                    }
                }
                .accessibilityLabel("QR Code")
                .listRowSeparator(.hidden)
                if !minimalistic {
                    let amountStr = amount.formatted(specs: specs, isNegative: false)
                    let scanLong = incoming ? String(localized: "(payer) 1",
                                                  defaultValue: "Let the payer scan this QR code to pay \(amountStr).",
                                                       comment: "e.g. '5,3 €'")
                                            : String(localized: "(payee) 1",
                                                  defaultValue: "Let the payee scan this QR code to receive \(amountStr).",
                                                       comment: "e.g. '$ 7.41'")
                    Text(scanLong)
                        .multilineTextAlignment(.leading)
                        .talerFont(.title3)
                        .listRowSeparator(.hidden)
                }
                CopyShare(textToCopy: talerCopyShare)
                    .disabled(false)
//                  .padding(.bottom)
                    .listRowSeparator(.hidden)
                
            }
        }
    }
}
// MARK: -
#if DEBUG
//fileprivate struct ContentView: View {
//    @State var previewURI: String = "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520"
//
//    var body: some View {
//        let amount = Amount(currency: LONGCURRENCY, cent: 123)
//        List {
//            QRCodeDetailView(talerURI: previewURI, talerCopyShare: previewURI, incoming: false, amount: amount)
//        }
//    }
//}
//struct QRCodeDetailView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        ContentView()
//    }
//}
#endif
