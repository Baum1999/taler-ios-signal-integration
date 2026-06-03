/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
//    @State var transaction: Transaction?
//    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var talerTX: TalerTransaction = TalerTransaction(dummyCurrency: DEMOCURRENCY)

    @MainActor
    private func viewDidLoad() async {
        symLog.log(".task")
        if let result = try? await model.startRefundForUri(url: url.absoluteString) {
            refundTransactionId = result
//            transaction = try? await model.getTransactionById(result)
        }
    }

    var body: some View {
        ZStack {
            if let refundTransactionId {    //, let transaction {
//            let common = transaction.common
//            let scope = common.scopes[0]              // TODO: tx could span multiple scopes
//            let raw = common.amountRaw
//            let currency = raw.currencyStr

                TransactionSummaryList(stack: stack.push(),
//                                     scope: scope,
                            transactionId: refundTransactionId,
                                  talerTX: $talerTX,
                                 navTitle: nil,   // navTitle,
                                  hasDone: true,
                                 showDone: .prominent,
                              withActions: true)
//                .task(id: controller.currencyTicker) {
//                    currencyInfo = controller.info2(for: currency, controller.currencyTicker)
//                }
            } else {
                LoadingView(stack: stack.push(), scopeInfo: nil, message: url.host)
                    .task { await viewDidLoad() }
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_REFUND)
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
