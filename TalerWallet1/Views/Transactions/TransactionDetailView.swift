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

    var transaction: Transaction
    var deleteAction: ((_ transactionId: String) async throws -> Void)?
    var abortAction: ((_ transactionId: String) async throws -> Void)?
    var doneAction: (() -> Void)?

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = transaction.common
        let pending = transaction.isPending
        let dateString = TalerDater.dateString(from: common.timestamp)
        let navTitle = (pending ? String(localized: "Pending ") : "") + "\(common.type)"   // TODO: localize type

        Group {
            List {
                Text("\(dateString)")
                    .font(.title2)
//                .listRowSeparator(.hidden)
                SwitchCase(transaction: transaction, common: common)

                if transaction.isAbortable { if let abortAction {
                    AbortButton(common: common, abortAction: abortAction)
                } }
                if transaction.isDeleteable { if let deleteAction {
                    DeleteButton(common: common, deleteAction: deleteAction)
                } }

                if let doneAction {
                    DoneButton(doneAction: doneAction)
                        .onNotification(.TransactionStateTransition) { notification in
print(notification.userInfo)
                            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
print(transition.newTxState.major)
                                if transition.transactionId == common.transactionId {
                                    doneAction()
                                }
                            }
                        }
                }
//                if transaction.isSuspendable { if let suspendAction {
//                    SuspendButton(common: common, suspendAction: suspendAction)
//                } }
//                if transaction.isResumable { if let resumeAction {
//                    ResumeButton(common: common, resumeAction: resumeAction)
//                } }
            }
            .listStyle(myListStyle.style).anyView
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
        let transaction: Transaction
        let common: TransactionCommon

        var body: some View {
            let pending = (common.txState.major == TransactionMajorState.pending)
            switch transaction {
                case .withdrawal(let withdrawalTransaction):
                    let details = withdrawalTransaction.details
                    if pending {
                        switch details.withdrawalDetails.type {
                            case .manual:
                                ManualDetails(common: common, details: details.withdrawalDetails)

                            case .bankIntegrated:
                                QRCodeDetails(transaction: transaction)
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
    struct DeleteButton: View {
        var common : TransactionCommon
        var deleteAction: (_ transactionId: String) async throws -> Void

        @State var disabled: Bool = false
        @State var deleted: Bool = false
        var body: some View {
            Button(role: .destructive, action: {
                Task {                  // delete from wallet-core
                    disabled = true     // don't try this more than once
                    do {
                        try await deleteAction(common.transactionId)
//                        symLog.log("deleted \(common.transactionId)")
                        deleted = true
                    } catch {    // TODO: error
//                        symLog.log(error.localizedDescription)
                    }
                }
            }, label: {
                HStack {
                    if deleted {
                        Text("Deleted from list")
                    } else {
                        Text("Delete from list" + "        ")
                        Image(systemName: "trash")
                    }
                }
                .font(.title)
                .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(disabled)
        }
    }
    struct AbortButton: View {
        var common : TransactionCommon
        var abortAction: (_ transactionId: String) async throws -> Void

        @State var disabled: Bool = false
        @State var aborting: Bool = false
        var body: some View {
            Button(role: .cancel, action: {
                Task {                  // delete from wallet-core
                    disabled = true     // don't try this more than once
                    do {
                        try await abortAction(common.transactionId)
//                        symLog.log("aborted \(common.transactionId)")
                        aborting = true
                    } catch {    // TODO: error
//                        symLog.log(error.localizedDescription)
                    }
                }
            }, label: {
                HStack {
                    if aborting {
                        Text("Abort pending...")
                    } else {
                        Text("Abort" + "        ")
                        Image(systemName: "x.circle")
                    }
                }
                .font(.title)
                .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(disabled)
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
    static var previews: some View {
        Group {
            TransactionDetailView(transaction: withdrawal, doneAction: doneActionDummy)
            TransactionDetailView(transaction: payment, deleteAction: deleteTransactionDummy)
        }
    }
}
#endif
