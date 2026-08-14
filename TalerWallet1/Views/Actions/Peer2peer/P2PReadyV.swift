/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when initiating a P2P transaction: Send or Request(Invoice)
struct P2PReadyV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    let summary: String
    let iconID: String?
    let expireDays: UInt
    let outgoing: Bool
    let amountToTransfer: Amount
    @Binding var transactionStarted: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var transactionId: String? = nil
    @State private var initiationError: Error? = nil
    @State private var noTransaction: TalerTransaction? = nil
    @State private var talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY)
    @Namespace var namespace

    @MainActor
    private func viewDidLoad() async {
        symLog.log("viewDidLoad")
        guard transactionStarted == false else {
// TODO:    logger.warning("Trying to start P2P a second time")
            symLog.log("Yikes❗️ Trying to start P2P a second time")
            return
        }
        transactionStarted = true
        let timestamp = developerMode ? Timestamp.inSomeMinutes(expireDays > 20 ? (24*60)   // 24h
                                                              : expireDays > 5  ? 60        //  1h
                                                                                : 3)        //  3m
                                      : Timestamp.inSomeDays(expireDays)
        let purseExpiration = developerMode ? timestamp
                                 : outgoing ? nil : timestamp
        let terms = PeerContractTerms(amount: amountToTransfer,
                                     summary: summary,
                            purse_expiration: purseExpiration,
                                     icon_id: iconID)
        do {
            if outgoing {
                let response = try await model.initiatePeerPushDebit(scope: scope, terms: terms,
                                                               viewHandles: true)
                // will switch from WithdrawProgressView to TransactionSummaryList
                transactionId = response.transactionId
            } else {
                // scope is the exchange the user picked in the ScopePicker, and the one the
                // fee was computed for. nil (== wallet-core decides) only for global scope.
                let response = try await model.initiatePeerPullCredit(scope.url, terms: terms,
                                                                viewHandles: true)
                // will switch from WithdrawProgressView to TransactionSummaryList
                transactionId = response.transactionId
            }
        } catch {
            symLog.log("❗️ \(error), \(error.localizedDescription)")
            transactionStarted = false      // failed, so let the user try again
            initiationError = error         // we show it ourselves (viewHandles: true)
        }
    }

    func doneAction() {
        dismissTop(stack.push())
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let navTitle = String(localized: "Ready")
        ZStack {
            if let transactionId {
                TransactionSummaryList(stack: stack.push(),
//                                     scope: scope,
                               transactionId: transactionId,
                                     talerTX: $talerTX,
                                    navTitle: navTitle,
                                     hasDone: true,             // conclude p2p
                                    showDone: .prominent,
                                         url: nil,
                                 withActions: false)
            } else if let initiationError {
                // don't spin forever - the user can go back and start over
                ErrorView(stack.push(), error: initiationError, devMode: developerMode)
            } else {
#if DEBUG
                let message = amountToTransfer.currencyStr
#else
                let message: String? = nil
#endif
                LoadingView(stack: stack.push(), scopeInfo: scope, message: message)
                    .task { await viewDidLoad() }
            }
        }.onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_P2P_READY, stack: stack.push())
        }
        .onDisappear {
//            print("❗️ P2PReadyV onDisappear")
        }
#if OIM
            .overlay { if #available(iOS 16.4, *) {
                if controller.oimModeActive {
                    OIMp2pReadyView(stack: stack.push(),
                            transactionId: $transactionId,
                                  talerTX: talerTX,
                                    scope: scope,
                                   action: doneAction)
                    .environmentObject(NamespaceWrapper(namespace))             // keep OIMviews apart
                }
            } }
#endif
    }
}
// MARK: -
//struct SendNow_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            SendDoneV(stack: CallStack("Preview"),
//               amountToSend: Amount(currency: LONGCURRENCY, cent: 480),
//           amountToReceive: nil,
//                   summary: "some subject/purpose",
//                expireDays: 0)
//        }
//    }
//}
