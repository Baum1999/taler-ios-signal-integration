/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
    let url: URL
//    let scope: ScopeInfo?
    let transactionId: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var paymentDone: Bool = false
    @State private var paymentPending: Bool = false
    @State private var talerTX: TalerTransaction = TalerTransaction(dummyCurrency: DEMOCURRENCY)

    @MainActor
    private func viewDidLoad() async {
        if let confirmPayResult = try? await model.confirmPay(transactionId) {
//          symLog.log(confirmPayResult as Any)
            if confirmPayResult.type == "done" {
                controller.removeURL(url)
                paymentDone = true
            } else {
                controller.removeURL(url)    // TODO: pending might fail - in which case we might want to try again
                paymentPending = true
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ZStack {
            if paymentDone || paymentPending {
//                let navTitle = paymentDone ? String(localized: "Paid", comment: "Title, short")
//                                           : String(localized: "Pending", comment: "Title, short")
                TransactionSummaryList(stack: stack.push(),
//                                     scope: scope,
                               transactionId: transactionId,
                                     talerTX: $talerTX,
                                    navTitle: nil, // navTitle,            // use navTitle2
                                     hasDone: true,
                                    showDone: .bordered,
                                         url: nil,
                                 withActions: false)
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
