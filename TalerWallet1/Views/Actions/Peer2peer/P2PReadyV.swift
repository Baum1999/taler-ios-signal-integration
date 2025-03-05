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

// Called when initiating a P2P transaction: Send or Request(Invoice)
struct P2PReadyV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    let summary: String
    let expireDays: UInt
    let outgoing: Bool
    let amountToTransfer: Amount
    @Binding var transactionStarted: Bool

    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let navTitle = String(localized: "Ready")
    @State private var transactionId: String? = nil
    @State private var noTransaction: Transaction? = nil

    @MainActor
    private func initiateP2P() async {
        symLog.log(".task")
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
        let terms = PeerContractTerms(amount: amountToTransfer,
                                     summary: summary,
                            purse_expiration: timestamp)
        if outgoing {
            // TODO: let user choose baseURL
            if let response = try? await model.initiatePeerPushDebit(scope: scope, terms: terms) {
                // will switch from WithdrawProgressView to TransactionSummaryV
                transactionId = response.transactionId
            }
        } else {
            // TODO: let user choose baseURL
            if let response = try? await model.initiatePeerPullCredit(nil, terms: terms) {
                // will switch from WithdrawProgressView to TransactionSummaryV
                transactionId = response.transactionId
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionSummaryV(stack: stack.push(),
//                                    scope: scope,
                            transactionId: transactionId,
                           outTransaction: $noTransaction,
                                 navTitle: navTitle,
                                  hasDone: true,
                              abortAction: nil,
                             deleteAction: nil,
                               failAction: nil,
                            suspendAction: nil,
                             resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
                .safeAreaInset(edge: .bottom) {
                    Button("Done") { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
            } else {
#if DEBUG
                let message = amountToTransfer.currencyStr
#else
                let message: String? = nil
#endif
                LoadingView(stack: stack.push(), scopeInfo: scope, message: message)
            }
        }
        .navigationTitle(navTitle)
        .task { await initiateP2P() }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_READY, stack: stack.push())
//            print("❗️ P2PReadyV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PReadyV onDisappear")
        }
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
