/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

    var body: some View {
        if let refundTransactionId {
            TransactionSummaryV(stack: stack.push(),
                          transactionId: refundTransactionId,
                           reloadAction: reloadOneAction,
                               navTitle: nil,   // navTitle,
                                hasDone: true,
                            abortAction: model.abortTransaction,
                           deleteAction: model.deleteTransaction,
                             failAction: model.failTransaction,
                          suspendAction: model.suspendTransaction,
                           resumeAction: model.resumeTransaction)
            .safeAreaInset(edge: .bottom) {
                Button("Done", action: { dismissTop(stack.push()) } )           // ViewState.shared.popToRootView ?
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
            }
        } else {
            LoadingView(scopeInfo: nil, message: url.host)
                .task {
                    symLog.log(".task")
                    if let result = try? await model.startRefundForUriM(url: url.absoluteString) {
                        refundTransactionId = result
                    }
                }
        }
    }
}

// MARK: -
struct RefundURIView_Previews: PreviewProvider {
    static var previews: some View {
        let transactionId = "txn:refund:12345"
        let url = URL(string: "taler://refund/txId")!
        RefundURIView(stack: CallStack("Preview"), url: url, refundTransactionId: transactionId)
    }
}
