/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called when accepting a scanned P2P transaction: Receive coins or Pay Request(Invoice)
struct P2pAcceptDone: View {
    private let symLog = SymLogV(0)

    let transactionId: String
    let incoming: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller

    @State private var finished: Bool = false

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let navTitle = incoming ? String(localized: "Received P2P", comment: "Title, short")
                                : String(localized: "Paid P2P", comment: "Title, short")
        TransactionDetailView(transactionId: transactionId,
                               reloadAction: reloadOneAction,
                                   navTitle: navTitle,
                                 doneAction: { dismissTop() },
                                abortAction: nil,
                               deleteAction: nil,
                                 failAction: nil,
                              suspendAction: nil,
                               resumeAction: nil)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()           // can only use "Done" button to dismiss
            .navigationTitle(navTitle)
            .onAppear() {
                symLog.log("onAppear")
                DebugViewC.shared.setSheetID(incoming ? SHEET_RCV_P2P_ACCEPT
                                                      : SHEET_PAY_P2P_ACCEPT)
            }
            .task {
                do {
                    if incoming {
                        _ = try await model.acceptPeerPushCreditM(transactionId)
                    } else {
                        _ = try await model.confirmPeerPullDebitM(transactionId)
                    }
                    finished = true
                } catch {    // TODO: error
                    symLog.log(error.localizedDescription)
                    controller.playSound(0)
                }
            }
    }
}
// MARK: -
struct P2pAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        P2pAcceptDone(transactionId: "some ID", incoming: true)
    }
}
