/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called either when scanning a QR code or tapping the provided link
// from another user's Request(Invoice). We show the P2P details.
struct P2pPayURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var peerPullDebitResponse: PreparePeerPullDebitResponse?

    let navTitle = String(localized: "Pay Request", comment: "Nav Title")

    @MainActor
    private func viewDidLoad() async {
        do {
            symLog.log(".task")
            peerPullDebitResponse = try? await model.preparePeerPullDebit(url.absoluteString)
        }
    }

    var body: some View {
        VStack {
            if let peerPullDebitResponse {
                List {
                    let raw = peerPullDebitResponse.amountRaw
                    let effective = peerPullDebitResponse.amountEffective
                    let scope = peerPullDebitResponse.scopeInfo
                    let currency = raw.currencyStr
                    let fee = try! Amount.diff(raw, effective)
                    ThreeAmountsSection(stack: stack.push(),
                                        scope: scope,
                                     topTitle: String(localized: "Amount to pay:"),
                                    topAbbrev: String(localized: "Pay:", comment: "mini"),
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: fee,
                                  bottomTitle: String(localized: "Amount to be spent:"),
                                 bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false, pending: false, incoming: false,
                                      baseURL: nil,
                                   txStateLcl: nil,
                                      summary: peerPullDebitResponse.contractTerms.summary,
                                     merchant: nil,
                                     products: nil)
                    let expiration = peerPullDebitResponse.contractTerms.purse_expiration
                    let (dateString, date) = TalerDater.dateString(expiration, minimalistic)
                    let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
                    let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "VoiceOver")
                    Text("Expires: \(dateString)")
                        .talerFont(.body)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
//                .task(id: controller.currencyTicker) {
//                    let currency = peerPullDebitResponse.amountRaw.currencyStr
//                    currencyInfo = controller.info2(for: currency, controller.currencyTicker)
//                }
                .safeAreaInset(edge: .bottom) {
                    let destination = P2pAcceptDone(stack: stack.push(),
                                            transactionId: peerPullDebitResponse.transactionId,
                                                 incoming: false)
                    NavigationLink(destination: destination) {
                        Text("Confirm Payment", comment:"pay P2P request/invoice")      // SHEET_PAY_P2P
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
                }
            } else {
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(scopeInfo: nil, message: message)
                    .task { await viewDidLoad() }
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
