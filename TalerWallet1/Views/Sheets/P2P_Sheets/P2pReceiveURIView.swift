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

    // the scanned URL
    let url: URL
    
    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var peerPushCreditResponse: PreparePeerPushCreditResponse? = nil
    @State private var exchange: Exchange? = nil

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if let peerPushCreditResponse {
                List {
                    let raw = peerPushCreditResponse.amountRaw
                    let effective = peerPushCreditResponse.amountEffective
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsV(topTitle: String(localized: "Amount to receive:"),
                                 topAbbrev: String(localized: "Receive:"),
                                 topAmount: raw, fee: fee,
                               bottomTitle: String(localized: "Amount to obtain:"),
                              bottomAbbrev: String(localized: "Effective:"),
                              bottomAmount: effective,
                                     large: false, pending: false, incoming: true,
                                   baseURL: nil)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
                let tosAccepted = exchange?.tosStatus == .accepted
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
                        exchangeBaseUrl: peerPushCreditResponse.exchangeBaseUrl,
                                 viewID: SHEET_RCV_P2P_TOS,
                                    p2p: true)
                }
            } else {
                LoadingView(url: url, message: nil)
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_RCV_P2P)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let ppResponse = try await model.preparePeerPushCreditM(url.absoluteString)
                exchange = await model.getExchangeByUrl(url: ppResponse.exchangeBaseUrl)
                peerPushCreditResponse = ppResponse
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPushCreditResponse = nil
            }
        }
    }
}
