/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called either when scanning a QR code or tapping the provided link
// from another user's Send Request(Invoice). We show the P2P details.
struct P2pPayURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Pay P2P")

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var peerPullDebitResponse: PreparePeerPullDebitResponse?

    var body: some View {
        VStack {
            if let peerPullDebitResponse {
                List {
                    let raw = peerPullDebitResponse.amountRaw
                    let effective = peerPullDebitResponse.amountEffective
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsV(topTitle: String(localized: "Amount to pay:"),
                                 topAbbrev: String(localized: "Pay:"),
                                 topAmount: raw, fee: fee,
                               bottomTitle: String(localized: "Amount to be spent:"),
                              bottomAbbrev: String(localized: "Effective:"),
                              bottomAmount: effective,
                                     large: false, pending: false, incoming: false,
                                   baseURL: nil,
                                    status: nil,
                                   summary: peerPullDebitResponse.contractTerms.summary)
                    let expiration = peerPullDebitResponse.contractTerms.purse_expiration
                    let (dateString, date) = TalerDater.dateString(from: expiration)
                    let accessibilityDate = TalerDater.accessibilityDate(date) ?? dateString
                    let accessibilityLabel = String(localized: "Expires: \(accessibilityDate)")
                    Text("Expires: \(dateString)")
                        .accessibilityFont(.body)
                        .accessibilityLabel(accessibilityLabel)
//                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)

                NavigationLink(destination: LazyView {
                    P2pAcceptDone(stack: stack.push(),
                          transactionId: peerPullDebitResponse.transactionId,
                               incoming: false)
                    }) {
                        Text("Confirm Payment", comment:"pay P2P request/invoice")      // SHEET_PAY_P2P
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
            } else {
                LoadingView(url: url, message: nil)
                    .task { do {
                        symLog.log(".task")
                        let ppDebitResponse = try await model.preparePeerPullDebitM(url.absoluteString)
                        peerPullDebitResponse = ppDebitResponse
                    } catch {    // TODO: error
                        symLog.log(error.localizedDescription)
                        peerPullDebitResponse = nil
                    } }
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_P2P)
        }
    }
}
// MARK: -
//#Preview {
//    P2pPayURIView(url: <#T##URL#>, model: <#T##WalletModel#>)
//}
