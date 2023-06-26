/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct P2pAcceptDone: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Received P2P")

    let transactionId: String

    @EnvironmentObject private var model: WalletModel

    @State private var finished: Bool = false

    func playSound(success: Bool) {
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/"
                      + (success ? "PaymentReceived.caf"
                                 : "payment_failure.caf"))
        GNU_Taler.playSound(fileURL: url)
    }

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            TransactionDetailView(transactionId: transactionId,
                                   reloadAction: reloadOneAction,
                                     doneAction: { dismissTop() })
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()           // can only use "Done" button to dismiss
            .navigationTitle(navTitle)
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_RCV_P2P_ACCEPT)
        }.task {
            do {
                _ = try await model.acceptPeerPushCreditM(transactionId)
                finished = true
                playSound(success: true)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                playSound(success: false)
            }
        }
    }
}
// MARK: -
struct P2pAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        P2pAcceptDone(transactionId: "some ID")
    }
}
