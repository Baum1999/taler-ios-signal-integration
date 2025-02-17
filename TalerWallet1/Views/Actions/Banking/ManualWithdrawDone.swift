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

struct ManualWithdrawDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
//    let scope: ScopeInfo                                                        // TODO: use data from tx itself

    let baseURL: String
    let amountToTransfer: Amount
//    let restrictAge: Int?

    @EnvironmentObject private var model: WalletModel

    @State private var acceptManualWithdrawalResult: AcceptManualWithdrawalResult?
    @State private var transactionId: String?
    @State private var noTransaction: Transaction? = nil

    let navTitle = String(localized: "Wire Transfer")

    @MainActor
    private func viewDidLoad() async {
        if transactionId == nil {
            if let result = try? await model.acceptManualWithdrawal(amountToTransfer,
                                                           baseUrl: baseURL,
                                                       restrictAge: 0)
            { transactionId = result.transactionId }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionSummaryV(stack: stack.push(),
//                                    scope: scope,                               // TODO: use data from tx itself
                            transactionId: transactionId,
                           outTransaction: $noTransaction,
                                 navTitle: navTitle,
                                  hasDone: true,
                              abortAction: nil,
                             deleteAction: nil,
                               failAction: nil,
                            suspendAction: nil,
                             resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
//                .navigationTitle(navTitle)
                .safeAreaInset(edge: .bottom) {
                    Button("Done") { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                }
            } else {
                LoadingView(scopeInfo: nil, message: baseURL.trimURL)
                    .task { await viewDidLoad() }
            }
        }
        .onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_ACCEPT, stack: stack.push())
        }
    }
}

// MARK: -
#if DEBUG
fileprivate struct ManualWithdrawDone_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer : View {
        @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 510)
        @State private var previewD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)

    var body: some View {
        let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                      masterPub: "masterPub",
                                      scopeInfo: scopeInfo,
                                      paytoUris: [],
                                      tosStatus: .pending,
                            exchangeEntryStatus: .preset,
                           exchangeUpdateStatus: .initial,
                          ageRestrictionOptions: [])
        ManualWithdrawDone(stack: CallStack("Preview"),
//                           scope: scopeInfo,
                         baseURL: DEMOEXCHANGE,
                amountToTransfer: amountToTransfer)
    }
}

    static var previews: some View {
        BindingViewContainer()
    }
}
#endif
