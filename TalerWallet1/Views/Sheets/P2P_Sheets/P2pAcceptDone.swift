/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when accepting a scanned P2P transaction: Receive, or pay Request(Invoice)
struct P2pAcceptDone: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    let url: URL?
    let transactionId: String
    let incoming: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @MainActor
    private func viewDidLoad() async {
        if incoming {
            if let _ = try? await model.acceptPeerPushCredit(transactionId) {
                dismissTop(stack.push())
            }
        } else {
            if let _ = try? await model.confirmPeerPullDebit(transactionId) {
                dismissTop(stack.push())
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let navTitle = incoming ? String(localized: "Received", comment: "Nav Title, short")
                                : String(localized: "Paid", comment: "Nav Title, short")
        let message = String(localized: "Accepting...", comment: "loading")
        LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
            .navigationBarBackButtonHidden(true)
//            .interactiveDismissDisabled()           // can only use "Done" button to dismiss
            .navigationTitle(navTitle)
            .task { await viewDidLoad() }
            .onAppear() {
                symLog.log("onAppear")
                DebugViewC.shared.setSheetID(incoming ? SHEET_RCV_P2P_ACCEPT
                                                      : SHEET_PAY_P2P_CONFIRM)
            }
    }
}
// MARK: -
struct P2pAcceptDone_Previews: PreviewProvider {
    static var previews: some View {
        P2pAcceptDone(stack: CallStack("Preview"),
                        url: URL("taler://nothing"),
              transactionId: "some ID",
                   incoming: true)
    }
}
