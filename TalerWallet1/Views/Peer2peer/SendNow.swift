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

    @ObservedObject var model: Peer2peerModel
    @State var peerPushResponse: PeerPushResponse?

    @State var talerURI: String? = nil

    var body: some View {
        ScrollView {
            if talerURI == nil {
                LoadingView(backButtonHidden: true)
            } else {
                VStack() {
                    Text("Let the payee scan this QR code to receive:")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 30)
                        .font(.title3)

                    QRGeneratorView(text: talerURI!)

                    Text("Alternatively, copy and send this URI:")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.title3)
                        .padding(.vertical)

                    Text(talerURI!)
                        .padding(.bottom)

                    CopyShare(textToCopy: talerURI!, dismissFirst: true)
                        .disabled(false)

                    Text("The QR code can also be copied and shared from Transactions later")
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline)
                        .padding(.vertical, 20)

                    Button("Done") {
                        dismissTop()
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.vertical)

                }
                .interactiveDismissDisabled()       // can only use "Done" button to dismiss
                .navigationBarHidden(true)          // no back button, no title
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .task {
            symLog.log(".task")
            do {
                // generate talerURI
                let timestamp = Timestamp.inSomeDays(expireDays)
                let terms = PeerContractTerms(amount: amountToSend, summary: purpose, purse_expiration: timestamp)
                let baseURL = DEMOEXCHANGE  // TODO: use correct baseURL
                peerPushResponse = try await model.initiatePeerPushDebitM(baseURL, terms: terms)
                talerURI = peerPushResponse?.talerUri
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
//            SendNow()
//            SendNow(talerURI: "taler://pay-push/exchange.demo.taler.net")
//        }
//    }
//}
