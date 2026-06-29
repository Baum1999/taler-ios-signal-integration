/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var peerPullDebitResponse: PreparePeerPullDebitResponse?

    let navTitle = String(localized: "Pay Request", comment: "Nav Title")

    @MainActor
    private func viewDidLoad() async {
        do {
            symLog.log(".task")
            let response = try? await model.preparePeerPullDebit(url.absoluteString)
            if let response {
                controller.removeURL(url)       // tx is now saved by wallet-core
            }
            peerPullDebitResponse = response
        }
    }

    var body: some View {
        VStack {
            if let peerPullDebitResponse {
                List {
                    PeerPullDebitView(stack: stack.push(),
                                        raw: peerPullDebitResponse.amountRaw,
                                  effective: peerPullDebitResponse.amountEffective,
                                     isDone: false,
                                      scope: peerPullDebitResponse.scopeInfo,
                                    summary: peerPullDebitResponse.contractTerms.summary)
                    let expiration = peerPullDebitResponse.contractTerms.purse_expiration
                    ExpiresView(expiration: expiration)
                }
                .listStyle(myListStyle.style).anyView
                .navigationTitle(navTitle)
//                .task(id: controller.currencyTicker) {
//                    let currency = peerPullDebitResponse.amountRaw.currencyStr
//                    currencyInfo = controller.info2(for: currency, controller.currencyTicker)
//                }
                .safeAreaInset(edge: .bottom) {
                    if peerPullDebitResponse.txState.isConfirmed {
                        Button("Done") { dismissTop(stack.push()) }
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                    } else {
                        PeerPullDebitConfirm(stack: stack.push(), url: url,
                                     transactionId: peerPullDebitResponse.transactionId)
                    }
                }
            } else {
#if DEBUG
                let message = url.host
#else
                let message: String? = nil
#endif
                LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                    .task { await viewDidLoad() }
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_P2P, stack: stack.push())
        }
    }
}
// MARK: -
//#Preview {
//    P2pPayURIView(url: <#T##URL#>, model: <#T##WalletModel#>)
//}
// MARK: -
struct PeerPullDebitConfirm: View  {
    let stack: CallStack
    let url: URL?
    let transactionId: String

    var body: some View {
        let destination = P2pAcceptDone(stack: stack.push(),
                                          url: url,
                                transactionId: transactionId,
                                     incoming: false)
        NavigationLink(destination: destination) {
            Text("Confirm Payment", comment:"pay P2P request/invoice")      // SHEET_PAY_P2P
        }
        .buttonStyle(TalerButtonStyle(type: .prominent))
        .padding(.horizontal)
    }
}
// MARK: -
struct PeerPullDebitView: View  {
    let stack: CallStack
//    let peerPullDebitResponse: PreparePeerPullDebitResponse
    let raw: Amount
    let effective: Amount
    let isDone: Bool
    let scope: ScopeInfo?
    let summary: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    var body: some View {
//        let raw = peerPullDebitResponse.amountRaw
//        let effective = peerPullDebitResponse.amountEffective
//        let scope = peerPullDebitResponse.scopeInfo
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
                            large: false,
                    pendingDialog: false,
                           isDone: isDone,
                         incoming: false,
                          baseURL: nil,
                       txStateLcl: nil,
                          summary: summary,
                         products: nil)
    }
}
