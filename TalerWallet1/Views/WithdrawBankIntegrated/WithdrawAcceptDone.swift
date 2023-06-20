/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawAcceptDone: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Confirm with Bank")

    let exchangeBaseUrl: String
    let model: WithdrawModel?
    let url: URL

    @State private var confirmTransferUrl: String? = nil
    @State private var transaction: Transaction? = nil

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        if let model {
            return try await model.getTransactionByIdT(transactionId)
        } else {
            throw WalletBackendError.walletCoreError
        }
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            if let transaction {
                TransactionDetailView(transaction: transaction,
                                     reloadAction: reloadOneAction,
                                       doneAction: { dismissTop() })
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
                .navigationTitle(navTitle)
            } else {
                WithdrawProgressView(message: "Bank Confirmation")
                    .navigationTitle("Loading...")
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_WITHDRAW_CONFIRM)
        }.task {
            do {
                if let model {
                    let result = try await model.sendAcceptIntWithdrawalM(exchangeBaseUrl, withdrawURL: url.absoluteString)
                    confirmTransferUrl = result!.confirmTransferUrl
                    transaction = try await model.getTransactionByIdT(result!.transactionId)
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
// MARK: -
struct WithdrawAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawAcceptDone(exchangeBaseUrl: DEMOEXCHANGE,
                           model: nil,
                           url: URL(string: DEMOSHOP)!)
    }
}
