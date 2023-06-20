/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog


struct SendNow: View {
    private let symLog = SymLogV()

    var amountToSend: Amount
    var purpose: String
    var expireDays: UInt

    var model: Peer2peerModel?
    @State var peerPushResponse: PeerPushResponse?

    @State var talerURI: String? = nil

    var body: some View {
        ScrollView {
            if talerURI == nil {
                LoadingView(backButtonHidden: true)
            } else {
                VStack() {
                    QRCodeDetailView(talerURI: talerURI!)

                    Text("The QR code can also be copied and shared from Transactions later")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline)
                        .padding(.vertical, 20)

                    Button("Done") {
                        ViewState.shared.popToRootView()
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.vertical)

                }
                .interactiveDismissDisabled()       // can only use "Done" button to dismiss
                .navigationBarHidden(true)          // no back button, no title
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal)
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            }
        }
        .task {
            symLog.log(".task")
            do {
                // generate talerURI
                if let model {
                    let timestamp = Timestamp.inSomeDays(expireDays)
                    let terms = PeerContractTerms(amount: amountToSend, summary: purpose, purse_expiration: timestamp)
                    // TODO: user might choose baseURL
                    peerPushResponse = try await model.initiatePeerPushDebitM(nil, terms: terms)
                    talerURI = peerPushResponse?.talerUri
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        } // task
    }
}
// MARK: -
//struct SendNow_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            SendNow(amountToSend: <#T##Amount#>,
//                    purpose: <#T##String#>,
//                    expireDays: <#T##UInt#>,
//                    model: <#T##Peer2peerModel#>,
//                    peerPushResponse: <#T##PeerPushResponse?#>,
//                    talerURI: "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520")
//        }
//    }
//}
