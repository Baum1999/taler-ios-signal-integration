/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called when initiating a P2P transaction: Send coins or Send Request(Invoice)
struct SendDoneV: View {
    private let symLog = SymLogV()
    let stack: CallStack
    let navTitle = String(localized: "P2P Ready")
    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let amountToSend: Amount?
    let amountToReceive: Amount?
    let summary: String
    let expireDays: UInt
    @Binding var transactionStarted: Bool

    @State private var transactionId: String? = nil

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ScrollView { VStack {
            if let transactionId {
                TransactionDetailView(stack: stack.push(),
                              transactionId: transactionId,
                               reloadAction: reloadOneAction,
                                   navTitle: navTitle,
                                 doneAction: ViewState.shared.popToRootView,
                                abortAction: nil,
                               deleteAction: nil,
                                 failAction: nil,
                              suspendAction: nil,
                               resumeAction: nil)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
            } else {
                WithdrawProgressView(message: "Loading...")
            }
        } } // ScrollVStack
//        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .task {
            symLog.log(".task")
            do {
                guard transactionStarted == false else {
// TODO:               logger.warning("Try to start P2P a second time")
                    symLog.log("Yikes❗️ Try to start P2P a second time")
                    return
                }
                transactionStarted = true
                let timestamp = developerMode ? Timestamp.inSomeMinutes(expireDays > 20 ? (24*60)
                                                                      : expireDays > 5 ? 60 : 3)
                                              : Timestamp.inSomeDays(expireDays)
                if let amountToSend {
                    let terms = PeerContractTerms(amount: amountToSend,
                                                 summary: summary,
                                        purse_expiration: timestamp)
                    // TODO: user might choose baseURL
                    let response = try await model.initiatePeerPushDebitM(nil, terms: terms)
                    // will switch from WithdrawProgressView to TransactionDetailView
                    transactionId = response.transactionId
                } else if let amountToReceive {
                    let terms = PeerContractTerms(amount: amountToReceive,
                                                 summary: summary,
                                        purse_expiration: timestamp)
                    // TODO: user might choose baseURL
                    let response = try await model.initiatePeerPullCreditM(nil, terms: terms)
                    // will switch from WithdrawProgressView to TransactionDetailView
                    transactionId = response.transactionId
                } else { fatalError() }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
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
