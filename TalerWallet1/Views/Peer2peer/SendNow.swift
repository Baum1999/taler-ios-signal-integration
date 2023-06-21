/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog


struct SendNow: View {
    private let symLog = SymLogV()

    let amountToSend: Amount?
    let amountToReceive: Amount?
    let summary: String
    let expireDays: UInt

    @EnvironmentObject private var model: WalletModel

    @State var talerURI: String = ""

    var body: some View {
        ScrollView {
            if talerURI.isEmpty {
                LoadingView(backButtonHidden: true)
            } else {
                VStack() {
                    QRCodeDetailView(talerURI: $talerURI, incoming: amountToSend == nil)

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
                let timestamp = Timestamp.inSomeDays(expireDays)
                if let amountToSend {
                    let terms = PeerContractTerms(amount: amountToSend,
                                                 summary: summary,
                                        purse_expiration: timestamp)
                    // TODO: user might choose baseURL
                    let response = try await model.initiatePeerPushDebitM(nil, terms: terms)
                    talerURI = response.talerUri
                } else if let amountToReceive {
                    let terms = PeerContractTerms(amount: amountToReceive,
                                                 summary: summary,
                                        purse_expiration: timestamp)
                    // TODO: user might choose baseURL
                    let response = try await model.initiatePeerPullCreditM(nil, terms: terms)
                    talerURI = response.talerUri
                } else { talerURI = "" }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                talerURI = ""
            }
        } // task
    }
}
// MARK: -
struct SendNow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SendNow(amountToSend: try! Amount(fromString: LONGCURRENCY + ":4.8"),
                    amountToReceive: nil,
                    summary: "some purpose",
                    expireDays: 0,
                    talerURI: "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520")
        }
    }
}
