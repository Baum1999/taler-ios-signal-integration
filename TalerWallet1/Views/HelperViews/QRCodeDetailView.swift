/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
    let scope: ScopeInfo

    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var currencyInfo: CurrencyInfo?

    private func currencyTickerChanged() async {
        currencyInfo = controller.info(for: scope)
    }

    private func amountStr(_ currencyInfo : CurrencyInfo?) -> (String, String) {
        let amountFormatted: (String, String)
        let readable = amount.readableDescription
        let myCurrencyInfo = currencyInfo ?? controller.info(for: scope)
        if let myCurrencyInfo {
            amountFormatted = amount.formatted(myCurrencyInfo, isNegative: false,
                                               useISO: false, a11yDecSep: nil)
        } else {
            amountFormatted = (readable, readable)
        }
        return amountFormatted
    }

    private func requesting(_ amountS: String) -> String {
        minimalistic ? String(localized: "(payer) 1 mini",
                           defaultValue: "Requesting \(amountS)",
                                comment: "e.g. '5,3 €'")
                     : String(localized: "(payer) 1",
                           defaultValue: "Scan this QR code to pay \(amountS)",
                                comment: "e.g. '5,3 €'")
    }
    private func sending(_ amountS: String) -> String {
        minimalistic ? String(localized: "(payee) 1 mini",
                           defaultValue: "Sending \(amountS)",
                                comment: "e.g. '$ 7.41'")
                     : String(localized: "(payee) 1",
                           defaultValue: "Scan this QR code to receive \(amountS)",
                                comment: "e.g. '$ 7.41'")
    }

    var body: some View {
        if talerURI.count > 10 {
            Section {
                Group {
//                    if #available(iOS 16.4, *) {
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
                .accessibilityLabel(Text("QR Code", comment: "a11y"))
                .listRowSeparator(.hidden)
                let amountStr = amountStr(currencyInfo)
                let scanLong = incoming ? (requesting(amountStr.0), requesting(amountStr.1))
                                        : (sending(amountStr.0), sending(amountStr.1))
                Text(scanLong.0)
                    .accessibilityLabel(scanLong.1)
                    .multilineTextAlignment(.leading)
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                    .task(id: controller.currencyTicker) { await currencyTickerChanged() }
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
