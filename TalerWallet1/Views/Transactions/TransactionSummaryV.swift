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
struct TransactionSummaryV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let transactionId: String
    let reloadAction: ((_ transactionId: String) async throws -> Transaction)
    let navTitle: String?
    let doneAction: ((_ stack: CallStack) -> Void)?
    let abortAction: ((_ transactionId: String) async throws -> Void)?
    let deleteAction: ((_ transactionId: String) async throws -> Void)?
    let failAction: ((_ transactionId: String) async throws -> Void)?
    let suspendAction: ((_ transactionId: String) async throws -> Void)?
    let resumeAction: ((_ transactionId: String) async throws -> Void)?

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State var transaction: Transaction = Transaction(dummyCurrency: DEMOCURRENCY)
    @State var viewId = UUID()

    func loadTransaction() async {
        do {
            let reloadedTransaction = try await reloadAction(transactionId)
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
                    doneAction(stack.push())        // if this view is in a sheet then dissmiss the sheet
                    return true
                }
            }
        } else { // no sheet but the details view -> reload
            checkReload(notification, logStr)
        }
        return false
    }

    func checkReload(_ notification: Notification, _ logStr: String = "") {
        if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
            if transition.transactionId == transactionId {       // is the transition for THIS transaction?
                let newMajor = transition.newTxState.major
                Task { // runs on MainActor
                       // flush the screen first, then reload
                    withAnimation() { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
                    symLog.log("newState: \(newMajor), reloading transaction")
                    await loadTransaction()
                }
            }
        } else { // Yikes - should never happen
// TODO:      logger.warning("Can't get notification.userInfo as TransactionTransition")
            symLog.log(notification.userInfo as Any)
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = transaction.common
        let pending = transaction.isPending
        let locale = TalerDater.shared.locale
        let (dateString, date) = TalerDater.dateString(from: common.timestamp)
        let accessibilityDate = TalerDater.accessibilityDate(date) ?? dateString
        let navTitle2 = transaction.isDone ? transaction.localizedTypePast
                                           : transaction.localizedType
        VStack {
            List {
                if developerMode {
                    if transaction.isSuspendable { if let suspendAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .suspend, warning: nil, action: suspendAction)
                    } }
                    if transaction.isResumable { if let resumeAction {
                        TransactionButton(transactionId: common.transactionId,
                                          command: .resume, warning: nil, action: resumeAction)
                    } }
                } // Suspend + Resume buttons
                Text(dateString)
                    .accessibilityFont(.body)
                    .accessibilityLabel(accessibilityDate)
                    .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                    .listRowSeparator(.hidden)
                VStack(alignment: .trailing) {
                    let majorState = common.txState.major.localizedState
#if DEBUG
                    let minorState = common.txState.minor?.localizedState ?? nil
                    let state = transaction.isPending ? minorState ?? majorState
                                                      : majorState
#else
                    let state = majorState
#endif
                    HStack {
                        Text(verbatim: "|")   // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                            .accessibilityHidden(true)
                            .foregroundColor(Color.clear)
                        Spacer()
                        Text("Status: \(state)")
                            .multilineTextAlignment(.trailing)
                    }
                }    .listRowSeparator(.automatic)
                    .accessibilityFont(.title)
                TypeDetail(stack: stack.push(),
                           transaction: $transaction, hasDone: doneAction != nil)

//                if transaction.isRetryable { if let retryAction {
//                    TransactionButton(transactionId: common.transactionId, command: .retry,
//                                      warning: nil, action: abortAction)
//                } } // Retry button
                if transaction.isAbortable { if let abortAction {
                    TransactionButton(transactionId: common.transactionId, command: .abort,
                                      warning: String(localized: "Are you sure you want to abort this transaction?"),
                                      action: abortAction)
                } } // Abort button
                if transaction.isFailable { if let failAction {
                    TransactionButton(transactionId: common.transactionId, command: .fail,
                                      warning: String(localized: "Are you sure you want to fail this transaction?"),
                                      action: failAction)
                } } // Fail button
                if transaction.isDeleteable { if let deleteAction {
                    TransactionButton(transactionId: common.transactionId, command: .delete,
                                      warning: String(localized: "Are you sure you want to delete this transaction?"),
                                      action: deleteAction)
                } } // Delete button
                if let doneAction {
                    Button(transaction.shouldConfirm ? "Confirm later" : "Done", action: { doneAction(stack.push()) } )
                        .buttonStyle(TalerButtonStyle(type: transaction.shouldConfirm ? .bordered : .prominent))
                } // Done button
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
        } // Group
        .onNotification(.TransactionExpired) { notification in
            // TODO: Alert user that this tx just expired
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
        .onNotification(.PendingReady) { notification in
            checkReload(notification, "pending ready ==> reload for talerURI")
        }
        .onNotification(.TransactionStateTransition) { notification in
            checkReload(notification, "some transition ==> reload")
        }
        .navigationTitle(navTitle ?? navTitle2)
        .task {
            symLog.log("task - load transaction")
            await loadTransaction()
        }
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONSUMMARY, stack: stack.push())
        }
        .onDisappear {
            symLog.log("onDisappear")
        }
    }
//}
//
//extension TransactionSummaryV {
    struct KycButton: View {
        let destination: URL
        @AppStorage("minimalistic") var minimalistic: Bool = false

        var body: some View {
            VStack(alignment: .leading) {  // Show Hint that User must pass KYC on website
                if !minimalistic {
                    Text("You need to pass a KYC procedure")
                        .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                        .multilineTextAlignment(.leading)                   // otherwise
                        .listRowSeparator(.hidden)
                }
                Link("Open KYC website", destination: destination)
                    .buttonStyle(TalerButtonStyle(type: .prominent, badge: NEEDS_KYC))
                    .accessibilityHint("Will go to KYC website to confirm this withdrawal.")
            }
        }
    }

    struct ConfirmationButton: View {
        let destination: URL
        @AppStorage("minimalistic") var minimalistic: Bool = false

        var body: some View {
            VStack(alignment: .leading) {  // Show Hint that User should Confirm on bank website
                if !minimalistic {
                    Text("The bank is waiting for your confirmation.")
//                        .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                        .multilineTextAlignment(.leading)                   // otherwise
                        .listRowSeparator(.hidden)
                }
                Link("Confirm now", destination: destination)
                    .buttonStyle(TalerButtonStyle(type: .prominent, badge: CONFIRM_BANK))
                    .accessibilityHint("Will go to bank website to confirm this withdrawal.")
            }
        }
    }

    struct TypeDetail: View {
        let stack: CallStack
        @Binding var transaction: Transaction
        let hasDone: Bool

        var body: some View {
            let common = transaction.common
            let pending = transaction.isPending
            Group {
                switch transaction {
                    case .dummy(_):
                        let title = EMPTYSTRING
                        Text(title)
                            .accessibilityFont(.body)
                    case .withdrawal(let withdrawalTransaction): Group {
                        let details = withdrawalTransaction.details
                        if pending {
                            if transaction.isPendingKYC {
                                if let kycUrl = common.kycUrl {
                                    if let destination = URL(string: kycUrl) {
                                        KycButton(destination: destination)
                                    }
                                }
                            }
                            let withdrawalDetails = details.withdrawalDetails
                            switch withdrawalDetails.type {
                                case .manual:               // "Make a wire transfer of \(amount) to"
                                    ManualDetailsV(common: common, details: withdrawalDetails)

                                case .bankIntegrated:       // "Confirm now" (with bank)
                                    if !transaction.isPendingKYC {              // cannot confirm if KYC is needed first
                                        let confirmed = withdrawalDetails.confirmed ?? false
                                        if !confirmed {
                                            if let confirmationUrl = withdrawalDetails.bankConfirmationUrl {
                                                if let destination = URL(string: confirmationUrl) {
                                                    ConfirmationButton(destination: destination)
                                    }   }   }   }
                            } // switch
                        } // ManualDetails or Confirm now (with bank)
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Chosen:", comment: "mini"),
                                        topTitle: String(localized: "Chosen amount to withdraw:"),
                                         baseURL: details.exchangeBaseUrl, large: false,
                                         summary: nil, merchant: nil)
                    }
                    case .deposit(let depositTransaction): Group {
                        let details = depositTransaction.details
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Deposit:", comment: "mini"),
                                          topTitle: String(localized: "Amount to deposit:"),
                                          baseURL: nil, large: true,            // TODO: baseURL
                                          summary: nil, merchant: nil)
                    }
                    case .payment(let paymentTransaction): Group {
                        let details = paymentTransaction.details
//                        TransactionDetailV(paymentTx: paymentTransaction)
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Price:", comment: "mini"),
                                        topTitle: String(localized: "Price (net):"),
                                         baseURL: nil, large: true,             // TODO: baseURL
                                         summary: details.info.summary,
                                        merchant: details.info.merchant.name)
                    }
                    case .refund(let refundTransaction): Group {
                        let details = refundTransaction.details                 // TODO: more details
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Refunded:", comment: "mini"),
                                        topTitle: String(localized: "Refunded amount:"),
                                         baseURL: nil, large: true,             // TODO: baseURL
                                         summary: details.info?.summary,
                                        merchant: details.info?.merchant.name)
                    }
                    case .reward(let rewardTransaction): Group {
                        let details = rewardTransaction.details
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Reward:", comment: "mini"),
                                        topTitle: String(localized: "Received Reward:"),
                                         baseURL: details.exchangeBaseUrl, large: true,
                                         summary: nil, merchant: nil)           // TODO: summary
                    }
                    case .refresh(let refreshTransaction): Group {
                        let details = refreshTransaction.details                // TODO: details
                        Text(details.refreshReason.rawValue)
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common, topAbbrev: String(localized: "Refreshed:", comment: "mini"),
                                        topTitle: String(localized: "Refreshed amount:"),
                                         baseURL: nil, large: true,             // TODO: baseURL
                                         summary: nil, merchant: nil)
                    }
                    case .peer2peer(let p2pTransaction): Group {
                        let details = p2pTransaction.details
                        let expiration = details.info.expiration
                        let (dateString, date) = TalerDater.dateString(from: expiration)
                        let accessibilityDate = TalerDater.accessibilityDate(date) ?? dateString
                        let accessibilityLabel = String(localized: "Expires: \(accessibilityDate)")
                        Text("Expires: \(dateString)")
                            .accessibilityFont(.body)
                            .accessibilityLabel(accessibilityLabel)
//                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                        // TODO: isSendCoins should show QR only while not yet expired  - either set timer or wallet-core should do so and send a state-changed notification
                        if pending {
                            if transaction.isPendingReady {
                                QRCodeDetails(transaction: transaction)
                                if hasDone {
                                    Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                                        .multilineTextAlignment(.leading)
                                        .accessibilityFont(.subheadline)
                                        .padding(.top)
                                }
                            } else {
                                Text("This transaction is not yet ready...")
                                    .multilineTextAlignment(.leading)
                                    .accessibilityFont(.subheadline)
                            }
                        }
                        let colon = ":"
                        let localizedType = transaction.isDone ? transaction.localizedTypePast
                                                               : transaction.localizedType
                        ThreeAmountsSheet(stack: stack.push(),
                                          common: common,
                                       topAbbrev: localizedType + colon,
                                        topTitle: localizedType + colon,
                                         baseURL: details.exchangeBaseUrl, large: false,
                                         summary: details.info.summary,
                                        merchant: nil)
                    } // p2p
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
//struct TransactionSummary_Previews: PreviewProvider {
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
//            TransactionSummaryV(transaction: withdrawal, reloadAction: reloadActionDummy, doneAction: doneActionDummy)
//            TransactionSummaryV(transaction: payment, reloadAction: reloadActionDummy, deleteAction: deleteTransactionDummy)
//        }
//    }
//}
#endif
