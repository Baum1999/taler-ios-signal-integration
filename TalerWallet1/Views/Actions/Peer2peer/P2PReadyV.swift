/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called when initiating a P2P transaction: Send coins or Send Request(Invoice)
struct P2PReadyV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
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

    let navTitle = String(localized: "P2P Ready")
    @State private var transactionId: String? = nil

    func reloadOneAction(_ transactionId: String, viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let transactionId {
                TransactionSummaryV(stack: stack.push(),
                             currencyInfo: $currencyInfo,
                              transactionId: transactionId,
                               reloadAction: reloadOneAction,
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
                LoadingView(scopeInfo: scope, message: message)
            }
        }
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_READY, stack: stack.push())
//            print("❗️ P2PReadyV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PReadyV onDisappear")
        }
        .task(id: amountToTransfer.value) {
            symLog.log(".task")
            guard transactionStarted == false else {
// TODO:               logger.warning("Try to start P2P a second time")
                symLog.log("Yikes❗️ Try to start P2P a second time")
                return
            }
            transactionStarted = true
            let timestamp = developerMode ? Timestamp.inSomeMinutes(expireDays > 20 ? (24*60)
                                                                  : expireDays > 5 ? 60 : 3)
                                          : Timestamp.inSomeDays(expireDays)
            let terms = PeerContractTerms(amount: amountToTransfer,
                                         summary: summary,
                                purse_expiration: timestamp)
            if outgoing {
                // TODO: let user choose baseURL
                if let response = try? await model.initiatePeerPushDebitM(scope: scope, terms: terms) {
                    // will switch from WithdrawProgressView to TransactionSummaryV
                    transactionId = response.transactionId
                }
            } else {
                // TODO: let user choose baseURL
                if let response = try? await model.initiatePeerPullCreditM(nil, terms: terms) {
                    // will switch from WithdrawProgressView to TransactionSummaryV
                    transactionId = response.transactionId
                }
            }
        } // task
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
