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

struct WithdrawAcceptDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let currencyInfo: CurrencyInfo

    let exchangeBaseUrl: String?
    let url: URL
    let amountToTransfer: Amount?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var transactionId: String? = nil
    @State private var transaction: Transaction? = nil

    let navTitle = String(localized: "Authorize with Bank", comment: "Nav title")

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        let response = try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
        transaction = response
        return response
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionSummaryV(stack: stack.push(),
                             currencyInfo: currencyInfo,
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
                .navigationTitle(navTitle)
                .safeAreaInset(edge: .bottom) {
                    if let transaction {
                        Button(transaction.shouldConfirm ? "Authorize later" : "Done", action: { dismissTop(stack.push()) } )
                            .buttonStyle(TalerButtonStyle(type: transaction.shouldConfirm ? .bordered : .prominent))
                            .padding(.horizontal)
                    } else {
                        Button("Cancel", action: { dismissTop(stack.push()) } )
                            .buttonStyle(TalerButtonStyle(type: .bordered))
                            .padding(.horizontal)
                    }
                }
            } else {
                LoadingView(scopeInfo: nil, message: exchangeBaseUrl?.trimURL()
                                                  ?? "Bank Authorization")
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_CONFIRM)
        }.task {
            if let exchangeBaseUrl {
                // TODO: restrictAge
                if let result = try? await model.sendAcceptIntWithdrawalM(exchangeBaseUrl, withdrawURL: url.absoluteString,
                                                                          amount: amountToTransfer, restrictAge: nil) {
                    let confirmTransferUrl = result.confirmTransferUrl
                    symLog.log(confirmTransferUrl)
                    transactionId = result.transactionId
                }
            }
        }
    }
}
// MARK: -
struct WithdrawAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawAcceptDone(stack: CallStack("Preview"),
                    currencyInfo: CurrencyInfo.zero(DEMOCURRENCY),
                 exchangeBaseUrl: DEMOEXCHANGE,
                             url: URL(string: DEMOSHOP)!,
                amountToTransfer: nil)
    }
}
