/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct ManualWithdrawDone: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Wire Transfer")

    var exchange: Exchange
    @ObservedObject var model: WithdrawModel
    var centsToTransfer: UInt64
    var restrictAge: Int?
    @State var acceptManualWithdrawalResult: AcceptManualWithdrawalResult?
    @State var withdrawalTransaction: Transaction?

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            if let transaction = withdrawalTransaction {
                TransactionDetailView(transaction: transaction,
                                       doneAction: {ViewState.shared.popToRootView()})
                .navigationBarBackButtonHidden(true)            // exit only by Done-Button
                .navigationTitle(navTitle)
            } else {
                WithdrawProgressView(message: exchange.exchangeBaseUrl.trimURL())
                    .navigationTitle("Loading " + navTitle)
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_ACCEPT)
        }.task {
            do {
                let amount = Amount.amountFromCents(exchange.currency!, centsToTransfer)
                let result = try await model.sendAcceptManualWithdrawalM(exchange.exchangeBaseUrl,
                                                                          amount: amount, restrictAge: restrictAge)
print(result as Any)
                let transaction = try await model.getTransactionById(transactionId: result!.transactionId)
                withdrawalTransaction = transaction
//                acceptManualWithdrawalResult = result
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}

// MARK: -
#if DEBUG
struct ManualWithdrawDone_Container : View {
    @State private var centsToTransfer: UInt64 = 510

    var body: some View {
        let model = WithdrawModel.model(baseURL: DEMOEXCHANGE)
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: "tosStatus",
                                 exchangeStatus: "exchangeStatus",
                          ageRestrictionOptions: [],
                                      permanent: false)
        ManualWithdrawDone(exchange: exchange,
                              model: model,
                    centsToTransfer: centsToTransfer)
    }
}

struct ManualWithdrawDone_Previews: PreviewProvider {
    static var previews: some View {
        ManualWithdrawDone_Container()
    }
}
#endif
