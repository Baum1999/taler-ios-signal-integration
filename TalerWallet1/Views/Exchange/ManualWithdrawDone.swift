/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct ManualWithdrawDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Wire Transfer")

    let exchange: Exchange
    let amountToTransfer: Amount
//    let restrictAge: Int?

    @EnvironmentObject private var model: WalletModel

    @State private var acceptManualWithdrawalResult: AcceptManualWithdrawalResult?
    @State private var transactionId: String?

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionDetailView(stack: stack.push(),
                              transactionId: transactionId,
                               reloadAction: reloadOneAction,
                                   navTitle: navTitle,
                                 doneAction: ViewState.shared.popToRootView,
                                abortAction: nil,
                               deleteAction: nil,
                                 failAction: nil,
                              suspendAction: nil,
                               resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
//                .navigationTitle(navTitle)
            } else {
                LoadingView(url: nil, message: exchange.exchangeBaseUrl.trimURL())
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_ACCEPT, stack: stack.push())
        }.task {
            do {
                let result = try await model.sendAcceptManualWithdrawalM(exchange.exchangeBaseUrl,
                                                                         amount: amountToTransfer, restrictAge: 0)
                transactionId = result!.transactionId
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}

// MARK: -
#if DEBUG
struct ManualWithdrawDone_Container : View {
    @State private var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 510)

    var body: some View {
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: .pending,
                            exchangeEntryStatus: .preset,
                           exchangeUpdateStatus: .initial,
                          ageRestrictionOptions: [])
        ManualWithdrawDone(stack: CallStack("Preview"),
                        exchange: exchange,
                amountToTransfer: amountToTransfer)
    }
}

struct ManualWithdrawDone_Previews: PreviewProvider {
    static var previews: some View {
        ManualWithdrawDone_Container()
    }
}
#endif
