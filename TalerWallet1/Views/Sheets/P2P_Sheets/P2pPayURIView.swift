/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link,
// from another user's SendInvoice. We show the P2P details.
struct P2pPayURIView: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Pay P2P Invoice")

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel

    @State private var peerPullDebitResponse: PreparePeerPullDebitResponse?

    var body: some View {
        VStack {
            if let peerPullDebitResponse {
                List {
                    let raw = peerPullDebitResponse.amountRaw
                    let effective = peerPullDebitResponse.amountEffective
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsView(topTitle: String(localized: "Amount to pay:"),
                                     topAmount: raw, fee: fee,
                                     bottomTitle: String(localized: "\(currency) to be spent:"),
                                     bottomAmount: effective,
                                     large: false, pending: false, incoming: false,
                                     baseURL: nil)
                }
                .navigationTitle(navTitle)

                NavigationLink(destination: LazyView {
                        P2pAcceptDone(transactionId: peerPullDebitResponse.transactionId)
                    }) {
                        Text("Confirm Payment", comment:"pay P2P invoice")      // SHEET_PAY_P2P
                    }.buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding()
            } else {
                // Yikes no details or no baseURL
                //                WithdrawProgressView(message: url.host ?? badURL)
                //                    .navigationTitle("Contacting Exchange")
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_P2P)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let ppDebitResponse = try await model.preparePeerPullDebitM(url.absoluteString)
                peerPullDebitResponse = ppDebitResponse
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPullDebitResponse = nil
            }
        }

    }
}
// MARK: -
//#Preview {
//    P2pPayURIView(url: <#T##URL#>, model: <#T##WalletModel#>)
//}
