/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

extension Transaction {             // for Dummys
    init(dummyCurrency: String) {
        let amount = try! Amount(fromString: "\(dummyCurrency):0")
        let now = Timestamp.now()
        let common = TransactionCommon(type: .dummy,
                                       txState: TransactionState(major: .pending),
                                       amountEffective: amount,
                                       amountRaw: amount,
                                       transactionId: "",
                                       timestamp: now,
                                       txActions: [])
        self = .dummy(DummyTransaction(common: common))
    }
}
// MARK: -
struct TransactionDetailView: View {
    private let symLog = SymLogV()
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("developerMode") var developerMode: Bool = false

    var transactionId: String
    @State var transaction: Transaction = Transaction(dummyCurrency: DEMOCURRENCY)
    @State var viewId = UUID()

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
                if developerMode {
                    if transaction.isSuspendable { if let suspendAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .suspend, action: suspendAction)
                    } }
                    if transaction.isResumable { if let resumeAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .resume, action: resumeAction)
                    } }
                } // Suspend + Resume buttons
                Text("\(dateString)")
                    .font(.title2)
//                .listRowSeparator(.hidden)
                SwitchCase(transaction: $transaction)

                if transaction.isAbortable { if let abortAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .abort, action: abortAction)
                } } // Abort button
                if transaction.isDeleteable { if let deleteAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .delete, action: deleteAction)
                } } // Delete button

                if let doneAction {
                    DoneButton(doneAction: doneAction)
                } // Done button
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
        }.onNotification(.TransactionStateTransition) { notification in
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == common.transactionId {
                    let newState = transition.newTxState.major
                    if newState == .done { if let doneAction {
                        symLog.log("newTxState.major == done  => dismiss sheet")
                        doneAction()        // if this view is in a sheet this action will dissmiss it
                    }} else { Task { do {
                        if doneAction != nil { // don't update while we are in a sheet - except done
                            symLog.log("ignoring newState: \(newState)")
                        } else {
                            symLog.log("newState: \(newState), reloading transaction")
                            withAnimation() { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
                            let reloadedTransaction = try await reloadAction(common.transactionId)
                            symLog.log("reloaded transaction: \(reloadedTransaction.common.txState.major)")
                            withAnimation() { transaction = reloadedTransaction; viewId = UUID() }      // redraw
                        }
                      } catch {
                          symLog.log(error.localizedDescription)
                    }}}
                }
            } else {
                // Yikes - should never happen
                symLog.log(notification.userInfo as Any)
            }
        }
        .navigationTitle(navTitle)
        .task {
            do {
                symLog.log("task - load transaction")
                let reloadedTransaction = try await reloadAction(transactionId)
                withAnimation() { transaction = reloadedTransaction; viewId = UUID() }      // redraw
            } catch {
                symLog.log(error)
                withAnimation() { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
            }
        }
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
                case .dummy(let dummyTransaction):
                    Text("")
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
                    } // ManualDetails or Confirm with bank
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
                    // TODO: isSendCoins should show QR only while not expired
                    if pending || transaction.isSendCoins {
                        QRCodeDetails(transaction: transaction)
                    }
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
                        QRCodeDetailView(talerURI: talerURI,
                                         incoming: transaction.isP2pIncoming)
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
//struct TransactionDetail_Previews: PreviewProvider {
//    static func deleteTransactionDummy(transactionId: String) async throws {}
//    static func doneActionDummy() {}
//    static var withdrawal = Transaction(incoming: true,
//                                         pending: true,
//                                              id: "some withdrawal ID",
//                                            time: Timestamp(from: 1_666_000_000_000))
//    static var payment = Transaction(incoming: false,
//                                      pending: false,
//                                           id: "some payment ID",
//                                         time: Timestamp(from: 1_666_666_000_000))
//    static func reloadActionDummy(transactionId: String) async -> Transaction { return withdrawal }
//    static var previews: some View {
//        Group {
//            TransactionDetailView(transaction: withdrawal, reloadAction: reloadActionDummy, doneAction: doneActionDummy)
//            TransactionDetailView(transaction: payment, reloadAction: reloadActionDummy, deleteAction: deleteTransactionDummy)
//        }
//    }
//}
#endif
