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

    let exchange: Exchange
    let centsToTransfer: UInt64
//    let restrictAge: Int?

    @EnvironmentObject private var model: WalletModel

    @State var acceptManualWithdrawalResult: AcceptManualWithdrawalResult?
    @State var transactionId: String?

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            if let transactionId {
                TransactionDetailView(transactionId: transactionId,
                                       reloadAction: reloadOneAction,
                                         doneAction: ViewState.shared.popToRootView)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
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
                                                                         amount: amount, restrictAge: 0)
                transactionId = result!.transactionId
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
        let exchange = Exchange(exchangeBaseUrl: DEMOEXCHANGE,
                                       currency: LONGCURRENCY,
                                      paytoUris: [],
                                      tosStatus: "tosStatus",
                                 exchangeStatus: "exchangeStatus",
                          ageRestrictionOptions: [],
                                      permanent: false)
        ManualWithdrawDone(exchange: exchange,
                    centsToTransfer: centsToTransfer)
    }
}

struct ManualWithdrawDone_Previews: PreviewProvider {
    static var previews: some View {
        ManualWithdrawDone_Container()
    }
}
#endif
