/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct PaymentDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let transactionId: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State var paymentDone: Bool = false

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }
    func dismissTopAnimated(_ stack: CallStack) {
        dismissTop()
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if paymentDone {
                let navTitle = String(localized: "Paid", comment: "Title, short")
                TransactionSummaryV(stack: stack.push(),
                            transactionId: transactionId,
                             reloadAction: reloadOneAction,
                                 navTitle: navTitle,
                               doneAction: dismissTopAnimated,
                              abortAction: nil,
                             deleteAction: nil,
                               failAction: nil,
                            suspendAction: nil,
                             resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
                .navigationTitle(navTitle)
            } else {
                LoadingView(url: nil, message: "Paying...")
                    .task {
                        do {
                            let confirmPayResult = try await model.confirmPayM(transactionId)
//                          symLog.log(confirmPayResult as Any)
                            if confirmPayResult.type == "done" {
                                paymentDone = true
                            } else {
                                controller.playSound(0)
                                // TODO: show error
                                dismissTop()
                            }
                        } catch {
                            controller.playSound(0)
                            // TODO: error
                            symLog.log(error.localizedDescription)
                            dismissTop()
                        }
                    }
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_ACCEPT)
        }
    }
}

// MARK: -
//#Preview {
//    PaymentDone(stack: CallStack("Preview"))
//}
