/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link,
// from another user's SendCoins. We show the P2P details - but first the ToS must be accepted.
struct P2pReceiveURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "P2P Receive")
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    // the scanned URL
    let url: URL
    
    @EnvironmentObject private var model: WalletModel

    @State private var peerPushCreditResponse: PreparePeerPushCreditResponse?

    var body: some View {
        VStack {
            if let peerPushCreditResponse {
                List {
                    let raw = peerPushCreditResponse.amountRaw
                    let effective = peerPushCreditResponse.amountEffective
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsView(topTitle: String(localized: "Amount to receive:"),
                                    topAbbrev: String(localized: "Receive:"),
                                    topAmount: raw, fee: fee,
                                  bottomTitle: String(localized: "Amount to be obtained:"),
                                 bottomAbbrev: String(localized: "Effective:"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: true,
                                      baseURL: nil)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                let tosAccepted = true  // TODO: https://bugs.gnunet.org/view.php?id=7869
                if tosAccepted {
                    NavigationLink(destination: LazyView {
                        P2pAcceptDone(stack: stack.push(),
                              transactionId: peerPushCreditResponse.transactionId,
                                   incoming: true)
                    }) {
                        Text("Accept P2P Receive")      // SHEET_RCV_P2P_ACCEPT
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
                } else {
                    ToSButtonView(stack: stack.push(),
                        exchangeBaseUrl: nil,
                                 viewID: SHEET_RCV_P2P_TOS,
                                    p2p: true)
                }
            } else {
                // Yikes no details or no baseURL
//                WithdrawProgressView(message: url.host ?? badURL)
//                    .navigationTitle("Contacting Exchange")
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_RCV_P2P)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let ppCreditResponse = try await model.preparePeerPushCreditM(url.absoluteString)
                peerPushCreditResponse = ppCreditResponse
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPushCreditResponse = nil
            }
        }
    }
}
