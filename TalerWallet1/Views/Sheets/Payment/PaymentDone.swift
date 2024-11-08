/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
    let scope: ScopeInfo?
    let transactionId: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State var paymentDone: Bool = false

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

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
                                    scope: scope,
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
                    Button("Done") { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
            } else {
                LoadingView(scopeInfo: nil, message: "Paying...")
                    .task { await viewDidLoad() }
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
