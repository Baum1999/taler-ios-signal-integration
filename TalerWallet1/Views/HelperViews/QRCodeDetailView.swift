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

    var body: some View {
        if talerURI.count > 10 {
            VStack {
                Text(incoming ? "Let the payer scan this QR code to pay:"
                              : "Let the payee scan this QR code to receive:")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 30)
                    .font(.title3)

                QRGeneratorView(text: talerURI)
//                Text(talerURI)

                Text("Alternatively, copy and send this URI:")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.title3)
                    .padding(.vertical)

                Text(talerURI)
                    .padding(.bottom)

                CopyShare(textToCopy: talerURI)
                    .disabled(false)
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
            QRCodeDetailView(talerURI: talerURI, incoming: false)
        }
    }
}
struct QRCodeDetailView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}
#endif
