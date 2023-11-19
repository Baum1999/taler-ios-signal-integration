/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

extension Transaction {             // for Dummys
    init(dummyCurrency: String) {
        let amount = Amount.zero(currency: dummyCurrency)
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
    private let symLog = SymLogV(0)
    let stack: CallStack
    let transactionId: String
    let reloadAction: ((_ transactionId: String) async throws -> Transaction)
    let navTitle: String?
    let doneAction: (() -> Void)?
    let abortAction: ((_ transactionId: String) async throws -> Void)?
    let deleteAction: ((_ transactionId: String) async throws -> Void)?
    let failAction: ((_ transactionId: String) async throws -> Void)?
    let suspendAction: ((_ transactionId: String) async throws -> Void)?
    let resumeAction: ((_ transactionId: String) async throws -> Void)?

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
//    @AppStorage("moreContrast") var moreContrast: Bool = false
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State var transaction: Transaction = Transaction(dummyCurrency: DEMOCURRENCY)
    @State var viewId = UUID()

    func accessibilityDate(_ date: Date?) -> String? {
        if let date {
            let formatted = date.formatted(date: .long, time: .shortened)
//            print(formatted)
            return formatted
        }
        return nil
    }

    func loadTransaction(_ txId: String) async {
        do {
            let reloadedTransaction = try await reloadAction(txId)
            symLog.log("reloaded transaction: \(reloadedTransaction.common.txState.major)")
            withAnimation() { transaction = reloadedTransaction; viewId = UUID() }      // redraw
        } catch {
            symLog.log(error.localizedDescription)
            withAnimation() { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
        }
    }

    @discardableResult
    func checkDismiss(_ notification: Notification, _ logStr: String = "") -> Bool {
        if let doneAction {
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == transaction.common.transactionId {       // is the transition for THIS transaction?
                    symLog.log(logStr)
                    doneAction()        // if this view is in a sheet then dissmiss the sheet
                    return true
                }
            }
        }
        return false
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = transaction.common
        let pending = transaction.isPending
        let locale = TalerDater.shared.locale
        let (dateString, date) = TalerDater.dateString(from: common.timestamp)
        let accessibilityDate = accessibilityDate(date) ?? dateString
        let navTitle2 = transaction.localizedType
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
                Text(dateString)
                    .accessibilityFont(.body)
                    .accessibilityLabel(accessibilityDate)
                    .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
//                    .foregroundColor(moreContrast ? .primary : .secondary)
                    .listRowSeparator(.hidden)
                HStack {
                    Text(verbatim: "|")   // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                        .accessibilityHidden(true)
                        .foregroundColor(Color.clear)
                    Spacer()
                    Text("Status: \(common.txState.major.localizedState)")
                }    .listRowSeparator(.automatic)
                    .accessibilityFont(.title)
                SwitchCase(transaction: $transaction, hasDone: doneAction != nil)

                if transaction.isAbortable { if let abortAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .abort, action: abortAction)
                } } // Abort button
                if transaction.isFailable { if let failAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .fail, action: failAction)
                } } // Fail button
                if transaction.isDeleteable { if let deleteAction {
                    TransactionButton(transactionId: common.transactionId,
                                      command: .delete, action: deleteAction)
                } } // Delete button
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
                .safeAreaInset(edge: .bottom) {
                    if let doneAction {
                        Button(transaction.shouldConfirm ? "Confirm later" : "Done", action: doneAction)
                            .buttonStyle(TalerButtonStyle(type: transaction.shouldConfirm ? .bordered : .prominent))
                            .padding(.horizontal)
                    }
                }
        }
        .onNotification(.TransactionExpired) { notification in
            if checkDismiss(notification, "newTxState.major == expired  => dismiss sheet") {
    // TODO:                  logger.info("newTxState.major == expired  => dismiss sheet")
            }
        }
        .onNotification(.TransactionDone) { notification in
            checkDismiss(notification, "newTxState.major == done  => dismiss sheet")
        }
        .onNotification(.DismissSheet) { notification in
            checkDismiss(notification, "exchangeWaitReserve or withdrawCoins  => dismiss sheet")
        }
        .onNotification(.TransactionStateTransition) { notification in
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == common.transactionId {       // is the transition for THIS transaction?
                    let newMajor = transition.newTxState.major
                    Task { // runs on MainActor
                        // flush the screen first, then reload
                        withAnimation() { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
                        symLog.log("newState: \(newMajor), reloading transaction")
                        await loadTransaction(common.transactionId)
                    }
                }
            } else { // Yikes - should never happen
// TODO:                logger.warning("Can't get notification.userInfo as TransactionTransition")
                symLog.log(notification.userInfo as Any)
            }
        }
        .navigationTitle(navTitle ?? navTitle2)
        .task {
            symLog.log("task - load transaction")
            await loadTransaction(transactionId)
        }
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONDETAIL, stack: stack.push())
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
        let hasDone: Bool
        @AppStorage("iconOnly") var iconOnly: Bool = false

        var body: some View {
            let common = transaction.common
            let pending = transaction.isPending
            Group {
                switch transaction {
                    case .dummy(_):
                        let title = ""
                        Text(title)
                            .accessibilityFont(.body)
                    case .withdrawal(let withdrawalTransaction):
                        let details = withdrawalTransaction.details
                        if pending {
                            let withdrawalDetails = details.withdrawalDetails
                            switch withdrawalDetails.type {
                                case .manual:               // "Make a wire transfer of \(amount) to"
                                    ManualDetailsV(common: common, details: withdrawalDetails)
                                    
                                case .bankIntegrated:       // "Confirm with bank"
                                    let confirmed = withdrawalDetails.confirmed ?? false
                                    if !confirmed {
                                        if let confirmationUrl = withdrawalDetails.bankConfirmationUrl {
                                            if let destination = URL(string: confirmationUrl) {
                                                VStack(alignment: .leading) {  // Show Hint that User should Confirm on bank website
                                                    if !iconOnly {
                                                        Text("Waiting for bank confirmation")
                                                            .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                                                            .multilineTextAlignment(.leading)                   // otherwise
                                                            .listRowSeparator(.hidden)
                                                    }
                                                    Link("Confirm with bank", destination: destination)
                                                        .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                                                        .padding(.horizontal)                                                    
                                                }
                                            }
                                        }
                                    } else if transaction.isPendingKYC {
                                        if let kycUrl = common.kycUrl {
                                            if let destination = URL(string: kycUrl) {
                                                VStack(alignment: .leading) {  // Show Hint that User must pass KYC on website
                                                    if !iconOnly {
                                                        Text("You need to pass a KYC procedure")
                                                            .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                                                            .multilineTextAlignment(.leading)                   // otherwise
                                                            .listRowSeparator(.hidden)
                                                    }
                                                    Link("Open KYC website", destination: destination)
                                                        .buttonStyle(TalerButtonStyle(type: .prominent, narrow: false, aligned: .center))
                                                        .padding(.horizontal)
                                                }
                                            }
                                        }
                                    }
                            } // switch
                        } // ManualDetails or Confirm with bank
                        ThreeAmountsSheet(common: common, topAbbrev: String(localized: "Chosen:"),
                                        topTitle: String(localized: "Chosen amount to withdraw:"),
                                         baseURL: details.exchangeBaseUrl, large: false)
                    case .payment(let paymentTransaction):
                        let details = paymentTransaction.details
                        Text(details.info.summary)
                            .accessibilityFont(.title2)
                            .lineLimit(4)
                            .padding(.bottom)
                        ThreeAmountsSheet(common: common, topAbbrev: String(localized: "Pay:"),
                                        topTitle: String(localized: "Sum to be paid:"),
                                         baseURL: nil, large: true)     // TODO: baseURL
                    case .refund(let refundTransaction):
                        let details = refundTransaction.details                 // TODO: more details
                        ThreeAmountsSheet(common: common, topAbbrev: String(localized: "Refunded:"),
                                        topTitle: String(localized: "Refunded amount:"),
                                         baseURL: nil, large: true)     // TODO: baseURL
                    case .reward(let rewardTransaction):
                        let details = rewardTransaction.details                 // TODO: more details
                        ThreeAmountsSheet(common: common, topAbbrev: String(localized: "Reward:"),
                                        topTitle: String(localized: "Received Reward:"),
                                         baseURL: details.exchangeBaseUrl, large: true)
                    case .refresh(let refreshTransaction):
                        let details = refreshTransaction.details                // TODO: details
                        ThreeAmountsSheet(common: common, topAbbrev: String(localized: "Refreshed:"),
                                        topTitle: String(localized: "Refreshed amount:"),
                                         baseURL: nil, large: true)     // TODO: baseURL
                    case .peer2peer(let p2pTransaction):
                        let details = p2pTransaction.details                    // TODO: details
                        Text(details.info.summary)
                            .accessibilityFont(.title2)
                            .lineLimit(4)
                            .padding(.bottom)
                        // TODO: isSendCoins should show QR only while not yet expired  - either set timer or wallet-core should do so and send a state-changed notification
                        if pending {
                            QRCodeDetails(transaction: transaction)
                            if hasDone {
                                Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                                    .multilineTextAlignment(.leading)
                                    .accessibilityFont(.subheadline)
                                    .padding(.top)
                            }
                        }
                        let colon = ":"
                        ThreeAmountsSheet(common: common, topAbbrev: transaction.localizedType + colon,
                                        topTitle: transaction.localizedType + colon,
                                         baseURL: details.exchangeBaseUrl, large: false)
                } // switch
            } // Group
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
                                         incoming: transaction.isP2pIncoming,
                                           amount: transaction.common.amountRaw)
                    }
                }
            } else if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    Text("from \(baseURL.trimURL())") 
                        .accessibilityFont(.title2)
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
