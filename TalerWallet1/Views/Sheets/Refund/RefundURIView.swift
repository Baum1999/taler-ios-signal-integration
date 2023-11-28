/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog
import taler_swift

struct RefundURIView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let url: URL

    @EnvironmentObject private var model: WalletModel

//    let navTitle = String(localized: "Refund", comment:"receive refund")

    @State var refundTransactionId: String? = nil

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
        if let refundTransactionId {
            TransactionDetailView(stack: stack.push(),
                          transactionId: refundTransactionId,
                           reloadAction: reloadOneAction,
                               navTitle: nil,   // navTitle,
                             doneAction: ViewState.shared.popToRootView,
                            abortAction: model.abortTransaction,
                           deleteAction: model.deleteTransaction,
                             failAction: model.failTransaction,
                          suspendAction: model.suspendTransaction,
                           resumeAction: model.resumeTransaction)
        } else {
            let badURL = "Error in Link: \(url)"
            WithdrawProgressView(message: url.host ?? badURL)
                .navigationTitle("Find Exchange")
                .task {
                    do {
                        symLog.log(".task")
                        let result = try await model.startRefundForUriM(url: url.absoluteString)
                        refundTransactionId = result
                    } catch {    // TODO: error
                        symLog.log(error.localizedDescription)
                    }
                }
        }
    }
}

// MARK: -
struct RefundURIView_Previews: PreviewProvider {
    static var previews: some View {
        let transactionId = "txn:refund:12345"
        let url = URL(string: "taler://reward/survey")!
        RefundURIView(stack: CallStack("Preview"), url: url, refundTransactionId: transactionId)
    }
}
