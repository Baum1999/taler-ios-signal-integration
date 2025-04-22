/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct PaymentDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
//    let scope: ScopeInfo?
    let transactionId: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var paymentDone: Bool = false
    @State private var noTransaction: TalerTransaction? = nil

    @MainActor
    private func viewDidLoad() async {
        if let confirmPayResult = try? await model.confirmPay(transactionId) {
//          symLog.log(confirmPayResult as Any)
            if confirmPayResult.type == "done" {
                paymentDone = true
            }
        }
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
//                                    scope: scope,
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
                .navigationTitle(navTitle)
                .safeAreaInset(edge: .bottom) {
                    Button("Done") { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
            } else {
                let message = String(localized: "Paying...", comment: "loading")
                LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                    .task { await viewDidLoad() }
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_CONFIRM)
        }
    }
}

// MARK: -
//#Preview {
//    PaymentDone(stack: CallStack("Preview"))
//}
