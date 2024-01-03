/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Confirm with Bank")

    let exchangeBaseUrl: String?
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var transactionId: String? = nil

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
            return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionDetailView(stack: stack.push(),
                              transactionId: transactionId,
                               reloadAction: reloadOneAction,
                                   navTitle: navTitle,
                                 doneAction: { dismissTop() },
                                abortAction: nil,
                               deleteAction: nil,
                                 failAction: nil,
                              suspendAction: nil,
                               resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
                .navigationTitle(navTitle)
            } else {
                LoadingView(url: nil, message: exchangeBaseUrl?.trimURL()
                                                    ?? "Bank Confirmation")
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_CONFIRM)
        }.task {
            do {
                if let exchangeBaseUrl {
                    let result = try await model.sendAcceptIntWithdrawalM(exchangeBaseUrl, withdrawURL: url.absoluteString)
                    let confirmTransferUrl = result!.confirmTransferUrl
                    symLog.log(confirmTransferUrl)
                    transactionId = result!.transactionId
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                controller.playSound(0)
            }
        }
    }
}
// MARK: -
struct WithdrawAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawAcceptDone(stack: CallStack("Preview"),
                 exchangeBaseUrl: DEMOEXCHANGE,
                             url: URL(string: DEMOSHOP)!)
    }
}
