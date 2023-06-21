/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct TransactionDetailView: View {
    private let symLog = SymLogV()
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("developerMode") var developerMode: Bool = false

    @State var transaction: Transaction
    var reloadAction: ((_ transactionId: String) async throws -> Transaction)
    var deleteAction: ((_ transactionId: String) async throws -> Void)?
    var abortAction: ((_ transactionId: String) async throws -> Void)?
    var doneAction: (() -> Void)?
    var suspendAction: ((_ transactionId: String) async throws -> Void)?
    var resumeAction: ((_ transactionId: String) async throws -> Void)?

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = transaction.common
        let pending = transaction.isPending
        let dateString = TalerDater.dateString(from: common.timestamp)
        let localizedType = transaction.localizedType
        let navTitle = pending ? String(localized: "Pending \(localizedType)")
                               : localizedType
        Group {
            List {
                Text("\(dateString)")
                    .font(.title2)
//                .listRowSeparator(.hidden)
                SwitchCase(transaction: $transaction)

                if transaction.isAbortable { if let abortAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .abort, action: abortAction)
                } }
                if transaction.isDeleteable { if let deleteAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .delete, action: deleteAction)
                } }

                if let doneAction {
                    DoneButton(doneAction: doneAction)
                }
                if developerMode {
                    if transaction.isSuspendable { if let suspendAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .suspend, action: suspendAction)
                    } }
                    if transaction.isResumable { if let resumeAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .resume, action: resumeAction)
                    } }
                }
            }.listStyle(myListStyle.style).anyView
        }.onNotification(.TransactionStateTransition) { notification in
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == common.transactionId {
                    let newState = transition.newTxState.major
                    if newState == .done { if let doneAction {
                        symLog.log("newTxState.major == done")
                        doneAction()
                    }} else { Task { do {
                        symLog.log("newState: \(newState), reloading transaction")
                        let reloadedTransaction = try await reloadAction(common.transactionId)
                        transaction = reloadedTransaction       // redraw
                      } catch {
                          symLog.log(error.localizedDescription)
                    }}}
                }
            } else {
                symLog.log(notification.userInfo as Any)
            }
        }
        .navigationTitle(navTitle)
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONDETAIL)
        }
        .onDisappear {
            symLog.log("onDisappear")
        }
    }
//}
//
//extension TransactionDetail {
    struct SwitchCase: View {
        @Binding var transaction: Transaction

        var body: some View {
            let common = transaction.common
            let pending = transaction.isPending
            switch transaction {
                case .withdrawal(let withdrawalTransaction):
                    let details = withdrawalTransaction.details
                    if pending {
                        let withdrawalDetails = details.withdrawalDetails
                        switch withdrawalDetails.type {
                            case .manual:               // "Make a wire transfer of \(amount) to"
                                ManualDetails(common: common, details: withdrawalDetails)

                            case .bankIntegrated:       // "Confirm with bank"
                                VStack {
                                    if let confirmationUrl = withdrawalDetails.bankConfirmationUrl {
                                        if let destination = URL(string: confirmationUrl) {
                                            // Show Hint that User should Confirm on bank website
                                            Text("Waiting for bank confirmation")
                                                .listRowSeparator(.hidden)
                                            Link("Confirm with bank", destination: destination)
                                                .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                                                .padding(.horizontal)

                                        }
                                    }
                                }
                        }
                    }
                    ThreeAmounts(common: common, topTitle: String(localized: "Chosen amount to withdraw:"),
                                baseURL: withdrawalTransaction.details.exchangeBaseUrl, large: true)
                case .payment(let paymentTransaction):
                    let details = paymentTransaction.details
                    let info = details.info
                    Text(info.summary)
                        .font(.title)
                        .lineLimit(4)
                        .padding(.bottom)
                    ThreeAmounts(common: common, topTitle: String(localized: "Sum to be paid:"),
                                 baseURL: nil, large: true)     // TODO: baseURL
                case .refund(let refundTransaction):
                    let details = refundTransaction.details                 // TODO: more details
                    ThreeAmounts(common: common, topTitle: String(localized: "Refunded amount:"),
                                 baseURL: nil, large: true)     // TODO: baseURL
                case .reward(let rewardTransaction):
                    let details = rewardTransaction.details                 // TODO: more details
                    ThreeAmounts(common: common, topTitle: String(localized: "Received Reward:"),
                                 baseURL: details.exchangeBaseUrl, large: true)
//                case .tip(let tipTransaction):
//                    let details = tipTransaction.details                  // TODO: details
//                    ThreeAmounts(common: common, topTitle: String(localized: "Received Tip:"), large: true)
                case .refresh(let refreshTransaction):
                    let details = refreshTransaction.details                // TODO: details
                    ThreeAmounts(common: common, topTitle: String(localized: "Refreshed amount:"),
                                 baseURL: nil, large: true)     // TODO: baseURL
                case .peer2peer(let p2pTransaction):
                    let details = p2pTransaction.details                    // TODO: details
                    QRCodeDetails(transaction: transaction)
                    ThreeAmounts(common: common, topTitle: String(localized: "Peer to Peer:"),
                                 baseURL: details.exchangeBaseUrl, large: false)
            }
        }
    }

    struct QRCodeDetails: View {
        var transaction : Transaction
        var body: some View {
            let details = transaction.detailsToShow()
            let keys = details.keys
            if keys.contains(TALERURI) {
                if let talerURI = details[TALERURI] {
                    if talerURI.count > 10 {
                        VStack {
                            QRGeneratorView(text: talerURI)
                            Text(talerURI)
                        }
                    }
                }
            } else if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    Text("from \(baseURL.trimURL())")
                        .font(.title2)
                        .padding(.bottom)
                }
            }
        }
    }
    struct DoneButton: View {
        var doneAction: () -> Void

        var body: some View {
            Button("Done") {
                doneAction()
            }
            .buttonStyle(TalerButtonStyle(type: .prominent))
            .padding(.horizontal)
        }
    }
}
// MARK: -
#if DEBUG
struct TransactionDetail_Previews: PreviewProvider {
    static func deleteTransactionDummy(transactionId: String) async throws {}
    static func doneActionDummy() {}
    static var withdrawal = Transaction(incoming: true,
                                         pending: true,
                                              id: "some withdrawal ID",
                                            time: Timestamp(from: 1_666_000_000_000))
    static var payment = Transaction(incoming: false,
                                      pending: false,
                                           id: "some payment ID",
                                         time: Timestamp(from: 1_666_666_000_000))
    static func reloadActionDummy(transactionId: String) async -> Transaction { return withdrawal }
    static var previews: some View {
        Group {
            TransactionDetailView(transaction: withdrawal, reloadAction: reloadActionDummy, doneAction: doneActionDummy)
            TransactionDetailView(transaction: payment, reloadAction: reloadActionDummy, deleteAction: deleteTransactionDummy)
        }
    }
}
#endif
