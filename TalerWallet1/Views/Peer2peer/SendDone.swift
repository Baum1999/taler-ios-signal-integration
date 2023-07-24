/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SendDone: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "P2P Ready")
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let amountToSend: Amount?
    let amountToReceive: Amount?
    let summary: String
    let expireDays: UInt

    @EnvironmentObject private var model: WalletModel

    @State var talerURI: String = ""

    var body: some View {
        List {
            let incoming = (amountToSend == nil)
            QRCodeDetailView(talerURI: talerURI,
                             incoming: incoming,
                               amount: incoming ? amountToReceive : amountToSend)
            Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                .multilineTextAlignment(.leading)
                .font(.subheadline)
                .padding(.top)
        }
        .listStyle(myListStyle.style).anyView
        .safeAreaInset(edge: .bottom) {
            Button("Done") {
                withAnimation() { ViewState.shared.popToRootView() }
            }
            .buttonStyle(TalerButtonStyle(type: .prominent))
            .padding(.horizontal)
        }
        .overlay {
            if talerURI.isEmpty {
                LoadingView(backButtonHidden: true)
            }
        }
        .interactiveDismissDisabled()       // can only use "Done" button to dismiss
        .navigationBarBackButtonHidden(true)
        .navigationTitle(navTitle)
//        .navigationBarHidden(true)          // no back button, no title
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .task {
            symLog.log(".task")
            do {
                // generate talerURI
                let timestamp = developerMode ? Timestamp.inSomeMinutes(expireDays > 20 ? (24*60)
                                                                      : expireDays > 5 ? 60 : 3)
                                              : Timestamp.inSomeDays(expireDays)
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
            SendDone(amountToSend: try! Amount(fromString: LONGCURRENCY + ":4.8"),
                    amountToReceive: nil,
                    summary: "some purpose",
                    expireDays: 0,
                    talerURI: "taler://pay-push/exchange.demo.taler.net/95ZG4D1AGFGZQ7CNQ1V49D3FT18HXKA6HQT4X3XME9YSJQVFQ520")
        }
    }
}
