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

extension Transaction {             // for Dummys
    init(dummyCurrency: String) {
        let amount = Amount.zero(currency: dummyCurrency)
        let now = Timestamp.now()
        let common = TransactionCommon(type: .dummy,
                                    txState: TransactionState(major: .pending),
                            amountEffective: amount,
                                  amountRaw: amount,
                              transactionId: EMPTYSTRING,
                                  timestamp: now,
                                  txActions: [])
        self = .dummy(DummyTransaction(common: common))
    }
}
// MARK: -
struct TransactionSummaryV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    let transactionId: String
    let reloadAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)
    let navTitle: String?
    let hasDone: Bool
    let abortAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Void)?
    let deleteAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Void)?
    let failAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Void)?
    let suspendAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Void)?
    let resumeAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var ignoreThis: Bool = false
    @State private var didDelete: Bool = false
    @State var transaction = Transaction(dummyCurrency: DEMOCURRENCY)
    @State var viewId = UUID()
    @Namespace var topID

    func loadTransaction() async {
        if let reloadedTransaction = try? await reloadAction(transactionId, false) {
            symLog.log("reloaded transaction: \(reloadedTransaction.common.txState.major)")
            withAnimation { transaction = reloadedTransaction; viewId = UUID() }      // redraw
        } else {
            withAnimation{ transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
        }
    }

    @MainActor
    @discardableResult
    func checkDismiss(_ notification: Notification, _ logStr: String = EMPTYSTRING) -> Bool {
        if hasDone {
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == transaction.common.transactionId {       // is the transition for THIS transaction?
                    symLog.log(logStr)
                    dismissTop(stack.push())        // if this view is in a sheet then dissmiss the sheet
                    return true
                }
            }
        } else { // no sheet but the details view -> reload
            checkReload(notification, logStr)
        }
        return false
    }

    @MainActor
    private func dismiss(_ stack: CallStack) {
        if hasDone {        // if this view is in a sheet then dissmiss the whole sheet
            dismissTop(stack.push())
        } else {            // on a NavigationStack just pop
            presentationMode.wrappedValue.dismiss()
        }
    }

    func checkReload(_ notification: Notification, _ logStr: String = EMPTYSTRING) {
        if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
            if transition.transactionId == transactionId {       // is the transition for THIS transaction?
                let newMajor = transition.newTxState.major
                Task { // runs on MainActor
                       // flush the screen first, then reload
                    withAnimation { transaction = Transaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
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
        let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
        let navTitle2 = transaction.isDone ? transaction.localizedTypePast
                                           : transaction.localizedType
        ScrollViewReader { scrollView in
            List {
                if developerMode {
                    if transaction.isSuspendable { if let suspendAction {
                        TransactionButton(transactionId: common.transactionId,
                                                command: .suspend,
                                                warning: nil,
                                             didExecute: $ignoreThis,
                                                 action: suspendAction)
                    } }
                    if transaction.isResumable { if let resumeAction {
                        TransactionButton(transactionId: common.transactionId,
                                                command: .resume,
                                                warning: nil,
                                             didExecute: $ignoreThis,
                                                 action: resumeAction)
                    } }
                } // Suspend + Resume buttons
                Group {
                    Text(dateString)
                        .talerFont(.body)
                        .accessibilityLabel(a11yDate)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                        .id(topID)
                    let majorState = common.txState.major.localizedState
                    let minorState = common.txState.minor?.localizedState ?? nil
                    let state = developerMode ? transaction.isPending ? minorState ?? majorState
                                                                      : majorState
                                              : majorState
                    let statusT = Text(state)
                                    .multilineTextAlignment(.trailing)
                    let imageT = Text(common.type.icon())
                                    .accessibilityHidden(true)
                    let prefixT = Text("Status:")
                    let vLayout = VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            imageT
                            prefixT
                        } // Icon + State
                        statusT
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if #available(iOS 16.0, *) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: HSPACING) {
                                imageT
                                Spacer()
                                prefixT
                                statusT
                            }
                            vLayout
                        }
                    } else { vLayout } // view for iOS 15
                }   .listRowSeparator(.hidden)
                    .talerFont(.title)
                    .onAppear {     // doesn't work - view still jumps
//                        scrollView.scrollTo(topID)
//                        withAnimation { scrollView.scrollTo(topID) }
                    }

                TypeDetail(stack: stack.push(),
                    currencyInfo: $currencyInfo,
                     transaction: $transaction,
                         hasDone: hasDone)

                // TODO: Retry Countdown, Retry Now button
//                if transaction.isRetryable, let retryAction {
//                    TransactionButton(transactionId: common.transactionId, command: .retry,
//                                      warning: nil, action: abortAction)
//                } // Retry button
                if transaction.isAbortable, let abortAction {
                    TransactionButton(transactionId: common.transactionId,
                                            command: .abort,
                                            warning: String(localized: "Are you sure you want to abort this transaction?"),
                                         didExecute: $ignoreThis,
                                             action: abortAction)
                } // Abort button
                if transaction.isFailable, let failAction {
                    TransactionButton(transactionId: common.transactionId,
                                            command: .fail,
                                            warning: String(localized: "Are you sure you want to abandon this transaction?"),
                                         didExecute: $ignoreThis,
                                             action: failAction)
                } // Fail button
                if transaction.isDeleteable, let deleteAction {
                    TransactionButton(transactionId: common.transactionId,
                                            command: .delete,
                                            warning: String(localized: "Are you sure you want to delete this transaction?"),
                                         didExecute: $didDelete,
                                             action: deleteAction)
                    .onChange(of: didDelete) { wasDeleted in
                        if wasDeleted {
                            symLog.log("wasDeleted -> dismiss view")
                            dismiss(stack)
                        }
                    }
                } // Delete button
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
        } // ScrollViewReader
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

    struct PendingWithdrawalDetails: View {
        let stack: CallStack
        @Binding var transaction: Transaction
        let details: WithdrawalTransactionDetails

        var body: some View {
            let common = transaction.common
            if transaction.isPendingKYC {
                if let kycUrl = common.kycUrl {
                    if let destination = URL(string: kycUrl) {
                        LinkButton(destination: destination,
                                     hintTitle: String(localized: "You need to pass a KYC procedure."),
                                   buttonTitle: String(localized: "Open KYC website"),
                                      a11yHint: String(localized: "Will go to KYC website to permit this withdrawal."),
                                         badge: NEEDS_KYC)
            }   }   }
            let withdrawalDetails = details.withdrawalDetails
            switch withdrawalDetails.type {
                case .manual:               // "Make a wire transfer of \(amount) to"
                    ManualDetailsV(stack: stack.push(), common: common, details: withdrawalDetails)

                case .bankIntegrated:       // "Authorize now" (with bank)
                    if !transaction.isPendingKYC {              // cannot authorize if KYC is needed first
                        let confirmed = withdrawalDetails.confirmed ?? false
                        if !confirmed {
                            if let confirmationUrl = withdrawalDetails.bankConfirmationUrl {
                                if let destination = URL(string: confirmationUrl) {
                                    LinkButton(destination: destination,
                                                 hintTitle: String(localized: "The bank is waiting for your authorization."),
                                               buttonTitle: String(localized: "Authorize now"),
                                                  a11yHint: String(localized: "Will go to bank website to authorize this withdrawal."),
                                                     badge: CONFIRM_BANK)
                    }   }   }   }
            } // switch
        }
    }

    struct TypeDetail: View {
        let stack: CallStack
        @Binding var currencyInfo: CurrencyInfo
        @Binding var transaction: Transaction
        let hasDone: Bool
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var colorSchemeContrast
        @AppStorage("minimalistic") var minimalistic: Bool = false
        @State private var rotationEnabled = true

        func refreshFee(input: Amount, output: Amount) -> Amount? {
            do {
                let fee = try input - output
                return fee
            } catch {
                
            }
            return nil
        }

        func abortedHint(_ delay: RelativeTime?) -> String? {
            if let delay {
                if let microseconds = try? delay.microseconds() {
                    let days = microseconds / (24 * 3600 * 1000 * 1000)
                    if days > 0 {
                        return String(days)
                    }
                }
                return "a few"
            }
            return nil
        }

        var body: some View {
            let common = transaction.common
            let pending = transaction.isPending
            Group {
                switch transaction {
                    case .dummy(_):
                        let title = EMPTYSTRING
                        Text(title)
                            .talerFont(.body)
                        RotatingTaler(size: 100, progress: true, rotationEnabled: $rotationEnabled)
                            .frame(maxWidth: .infinity, alignment: .center)
                            // has its own accessibilityLabel
                    case .withdrawal(let withdrawalTransaction): Group {
                        let details = withdrawalTransaction.details
                        if common.isAborted && details.withdrawalDetails.type == .manual {
                            if let dayStr = abortedHint(details.withdrawalDetails.reserveClosingDelay) {
                                Text("The withdrawal was aborted.\nIf you have already sent money to the exchange, it will wire it back in \(dayStr) days.")
                                    .talerFont(.callout)
                            }
                        }
                        if pending {
                            PendingWithdrawalDetails(stack: stack.push(),
                                               transaction: $transaction,
                                                   details: details)
                        } // ManualDetails or Confirm now (with bank)
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Chosen:", comment: "mini"),
                                       topTitle: String(localized: "Chosen amount to withdraw:"),
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: true,
                                          large: false,
                                        summary: nil,
                                       merchant: nil)
                    }
                    case .deposit(let depositTransaction): Group {
                        let details = depositTransaction.details
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Deposit:", comment: "mini"),
                                       topTitle: String(localized: "Amount to deposit:"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: false,
                                          large: true,
                                        summary: nil,
                                       merchant: nil)
                    }
                    case .payment(let paymentTransaction): Group {
                        let details = paymentTransaction.details
                        TransactionPayDetailV(paymentTx: paymentTransaction)
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Price:", comment: "mini"),
                                       topTitle: String(localized: "Price (net):"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: false,
                                          large: true,
                                        summary: details.info.summary,
                                       merchant: details.info.merchant.name)
                    }
                    case .refund(let refundTransaction): Group {
                        let details = refundTransaction.details                 // TODO: more details
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Refunded:", comment: "mini"),
                                       topTitle: String(localized: "Refunded amount:"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: true,
                                          large: true,
                                        summary: details.info?.summary,
                                       merchant: details.info?.merchant.name)
                    }
                    case .refresh(let refreshTransaction): Group {
                        let labelColor = WalletColors().labelColor
                        let errorColor = WalletColors().errorColor
                        let details = refreshTransaction.details
                        Section {
                            Text(details.refreshReason.localizedRefreshReason)
                                .talerFont(.title)
                            let input = details.refreshInputAmount
                            AmountRowV(stack: stack.push(),
                                currencyInfo: $currencyInfo,
                                       title: minimalistic ? "Refreshed:" : "Refreshed amount:",
                                      amount: input,
                                  isNegative: nil,
                                       color: labelColor,
                                       large: true)
                            if let fee = refreshFee(input: input, output: details.refreshOutputAmount) {
                                AmountRowV(stack: stack.push(),
                                    currencyInfo: $currencyInfo,
                                           title: minimalistic ? "Fee:" : "Refreshed fee:",
                                          amount: fee,
                                      isNegative: fee.isZero ? nil : true,
                                           color: labelColor,
                                           large: true)
                            }
                            if let error = details.error {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(error.hint)
                                            .talerFont(.headline)
                                            .foregroundColor(errorColor)
                                            .listRowSeparator(.hidden)
                                        if let stack = error.stack {
                                            Text(stack)
                                                .talerFont(.body)
                                                .foregroundColor(errorColor)
                                                .listRowSeparator(.hidden)
                                        }
                                    }
                                    let stackStr = error.stack ?? EMPTYSTRING
                                    let errorStr = error.hint + "\n" + stackStr
                                    CopyButton(textToCopy: errorStr, vertical: true)
                                        .accessibilityLabel(Text("Copy the error", comment: "VoiceOver"))
                                        .disabled(false)
                                }
                            }
                        }
                    }

                    case .peer2peer(let p2pTransaction): Group {
                        let details = p2pTransaction.details
                        if !transaction.isDone {
                            let expiration = details.info.expiration
                            let (dateString, date) = TalerDater.dateString(from: expiration)
                            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
                            let a11yLabel = String(localized: "Expires: \(a11yDate)", comment: "VoiceOver")
                            Text("Expires: \(dateString)")
                                .talerFont(.body)
                                .accessibilityLabel(a11yLabel)
                                .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                        }
                        // TODO: isSendCoins should show QR only while not yet expired  - either set timer or wallet-core should do so and send a state-changed notification
                        if pending {
                            if transaction.isPendingReady {
                                QRCodeDetails(transaction: transaction, specs: currencyInfo.specs)
                                if hasDone {
                                    Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                                        .multilineTextAlignment(.leading)
                                        .talerFont(.subheadline)
                                        .padding(.top)
                                }
                            } else {
                                Text("This transaction is not yet ready...")
                                    .multilineTextAlignment(.leading)
                                    .talerFont(.subheadline)
                            }
                        }
                        let colon = ":"
                        let localizedType = transaction.isDone ? transaction.localizedTypePast
                                                               : transaction.localizedType
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: localizedType + colon,
                                       topTitle: localizedType + colon,
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,         // TODO: noFees
                                  feeIsNegative: true,
                                          large: false,
                                        summary: details.info.summary,
                                       merchant: nil)
                    } // p2p

                    case .recoup(let recoupTransaction): Group {
                        let details = recoupTransaction.details                 // TODO: more details
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Recoup:", comment: "mini"),
                                       topTitle: String(localized: "Recoup:"),
                                        baseURL: nil,
                                         noFees: nil,
                                  feeIsNegative: nil,
                                          large: true,             // TODO: baseURL, noFees
                                        summary: nil,
                                       merchant: nil)
                    }
                    case .denomLoss(let denomLossTransaction): Group {
                        let details = denomLossTransaction.details              // TODO: more details
                        ThreeAmountsSheet(stack: stack.push(),
                                   currencyInfo: $currencyInfo,
                                         common: common,
                                      topAbbrev: String(localized: "Lost:", comment: "mini"),
                                       topTitle: String(localized: "Money lost:"),
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,
                                  feeIsNegative: nil,
                                          large: true,             // TODO: baseURL, noFees
                                        summary: details.lossEventType.rawValue,
                                       merchant: nil)
                    }
                } // switch
            } // Group
        }
    }

    struct QRCodeDetails: View {
        var transaction : Transaction
        var specs: CurrencySpecification
        var body: some View {
            let details = transaction.detailsToShow()
            let keys = details.keys
            if keys.contains(TALERURI) {
                if let talerURI = details[TALERURI] {
                    if talerURI.count > 10 {
                        QRCodeDetailView(talerURI: talerURI,
                                   talerCopyShare: talerURI,
                                         incoming: transaction.isP2pIncoming,
                                           amount: transaction.common.amountRaw,
                                            specs: specs)
                    }
                }
            } else if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    Text("from \(baseURL.trimURL)") 
                        .talerFont(.title2)
                        .padding(.bottom)
                }
            }
        }
    }
} // TransactionSummaryV
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
