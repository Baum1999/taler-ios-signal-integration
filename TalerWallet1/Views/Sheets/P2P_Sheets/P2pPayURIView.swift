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
    let navTitle = String(localized: "Pay P2P", comment: "Nav Title")

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
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
                    ThreeAmountsSection(stack: stack.push(),
                                     topTitle: String(localized: "Amount to pay:"),
                                    topAbbrev: String(localized: "Pay:", comment: "mini"),
                                    topAmount: raw, fee: fee,
                                  bottomTitle: String(localized: "Amount to be spent:"),
                                 bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: false,
                                      baseURL: nil,
                                       noFees: nil,        // TODO: check baseURL for fees
                                   txStateLcl: nil,
                                      summary: peerPullDebitResponse.contractTerms.summary,
                                     merchant: nil)
                    let expiration = peerPullDebitResponse.contractTerms.purse_expiration
                    let (dateString, date) = TalerDater.dateString(from: expiration)
                    let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
                    let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "VoiceOver")
                    Text("Expires: \(dateString)")
                        .talerFont(.body)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
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
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(scopeInfo: nil, message: message)
                    .task { do {
                        symLog.log(".task")
                        peerPullDebitResponse = try? await model.preparePeerPullDebitM(url.absoluteString)
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
