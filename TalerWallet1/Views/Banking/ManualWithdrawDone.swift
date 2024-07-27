/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
    @Binding var currencyInfo: CurrencyInfo

    let exchange: Exchange
    let amountToTransfer: Amount
//    let restrictAge: Int?

    @EnvironmentObject private var model: WalletModel

    @State private var acceptManualWithdrawalResult: AcceptManualWithdrawalResult?
    @State private var transactionId: String?

    let navTitle = String(localized: "Wire Transfer")

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionSummaryV(stack: stack.push(),
                             currencyInfo: $currencyInfo,
                            transactionId: transactionId,
                             reloadAction: reloadOneAction,
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
                    Button("Done", action: { dismissTop(stack.push()) } )       // ViewState.shared.popToRootView ?
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                }
            } else {
                LoadingView(scopeInfo: nil, message: exchange.exchangeBaseUrl.trimURL())
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_ACCEPT, stack: stack.push())
        }.task {
            if transactionId == nil {
                if let result = try? await model.sendAcceptManualWithdrawalM(exchange.exchangeBaseUrl,
                                                                             amount: amountToTransfer, restrictAge: 0) {
                    transactionId = result.transactionId
                }
            }
        }
    }
}

// MARK: -
#if DEBUG
fileprivate struct ManualWithdrawDone_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer : View {
        @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 510)
        @State private var currencyInfoD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)

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
                    currencyInfo: $currencyInfoD,
                        exchange: exchange,
                amountToTransfer: amountToTransfer)
    }
}

    static var previews: some View {
        BindingViewContainer()
    }
}
#endif
