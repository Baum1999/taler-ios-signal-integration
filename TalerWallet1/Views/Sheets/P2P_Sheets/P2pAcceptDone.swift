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
    let stack: CallStack

    let transactionId: String
    let incoming: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let navTitle = incoming ? String(localized: "Received P2P", comment: "Title, short")
                                : String(localized: "Paid P2P", comment: "Title, short")
        LoadingView(url: nil, message: "Accepting...")
            .navigationBarBackButtonHidden(true)
//            .interactiveDismissDisabled()           // can only use "Done" button to dismiss
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
                    dismissTop()
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
        P2pAcceptDone(stack: CallStack("Preview"),
              transactionId: "some ID",
                   incoming: true)
    }
}
