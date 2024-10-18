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
    @EnvironmentObject private var controller: Controller

//    let navTitle = String(localized: "Refund", comment:"receive refund")

    @State var refundTransactionId: String? = nil
    @State var transaction: Transaction?
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

    var body: some View {
        if let refundTransactionId, let transaction {
            let common = transaction.common
            let raw = common.amountRaw
            let currency = raw.currencyStr
//            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
            TransactionSummaryV(stack: stack.push(),
                         currencyInfo: $currencyInfo,
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
                Button("Done") { dismissTop(stack.push()) }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
            }
            .task(id: controller.currencyTicker) {
                currencyInfo = controller.info(for: currency, controller.currencyTicker)
            }
        } else {
            LoadingView(scopeInfo: nil, message: url.host)
                .task {
                    symLog.log(".task")
                    if let result = try? await model.startRefundForUriM(url: url.absoluteString) {
                        refundTransactionId = result
                        transaction = try? await model.getTransactionByIdM(result)
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
