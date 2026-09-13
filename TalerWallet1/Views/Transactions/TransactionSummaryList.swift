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

extension TalerTransaction {             // for Dummys
    init(dummyCurrency: String) {
        let amount = Amount.zero(currency: dummyCurrency)
        let now = Timestamp.now()
        let common = TransactionCommon(type: .dummy,
                              transactionId: EMPTYSTRING,
                                  timestamp: now,
                                     scopes: [],
                                    txState: TransactionState(major: .pending),
                                  txActions: [],
                                  amountRaw: amount,
                            amountEffective: amount)
        self = .dummy(DummyTransaction(common: common))
    }
}
// MARK: -
struct TransactionSummaryList: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let transactionId: String
    @Binding var talerTX: TalerTransaction
    let navTitle: String?
    let hasDone: Bool                       // false: just old tx, true: the conclusion of an transaction
    let showDone: TalerButtonStyleType?
    let url: URL?                           // the scanned talerURL from PaymentView
    let withActions: Bool                   // true if called from pending or history, or refund

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dismiss) var dismiss     // call dismiss() to pop back
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var ignoreThis: Bool = false
    @State private var didDelete: Bool = false
    @State var jsonTransaction: String = EMPTYSTRING
    @State var viewId = UUID()
    @State private var selectedChoice: Int? = nil
    @State private var effective: Amount? = nil
    @State private var scope: ScopeInfo? = nil
    @State private var payNow: Bool = false
    @Namespace var topID

    func loadTransaction() async {
        if let reloadedTransaction = try? await model.getTransactionById(transactionId,
                                                    includeContractTerms: true, viewHandles: false) {
            symLog.log("reloaded \(reloadedTransaction.localizedType): \(reloadedTransaction.common.txState.major)")
            withAnimation {
                talerTX = reloadedTransaction;
                scope = reloadedTransaction.common.scopes.first
                viewId = UUID()      // redraw
            }
            if developerMode {
                if let json = try? await model.jsonTransactionById(transactionId,
                                              includeContractTerms: true, viewHandles: false) {
                    jsonTransaction = json
                } else {
                    jsonTransaction = EMPTYSTRING
                }
            }
        } else {
            withAnimation{ talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
            jsonTransaction = EMPTYSTRING
        }
    }

    private func payTransaction() async {
        if let confirmPayResult = try? await model.confirmPay(transactionId,
                                                  choiceIndex: selectedChoice) {
//          symLog.log(confirmPayResult as Any)
            if confirmPayResult.type == "done" {
                if let url {
                    controller.removeURL(url)
                }
            } else {
                if let url {
                    controller.removeURL(url)    // TODO: pending might fail - in which case we might want to try again
                }
            }
        }
    }

    @MainActor
    @discardableResult
    func checkDismiss(_ notification: Notification, _ logStr: String = EMPTYSTRING) -> Bool {
        if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
            if transition.transactionId == talerTX.common.transactionId {       // is the transition for THIS transaction?
                if transition.newTxState.major == .deleted {
                    dismissTop(stack.push())        // dissmiss the sheet / the navigation stack
                    return true
                }
                if hasDone {
                    symLog.log(logStr)
                    if talerTX.common.type.isPayment {
                        checkReload(stack.push("checkDismiss1"), notification, logStr)
                    } else {
                        dismissTop(stack.push())        // if this view is in a sheet then dissmiss the sheet
                        return true
                    }
                } else { // no sheet but the details view -> reload
                    checkReload(stack.push("checkDismiss2"), notification, logStr)
                }
            }
        }
        return false
    }

    @MainActor
    private func dismiss(_ stack: CallStack) {
        if hasDone {        // if this view is in a sheet then dissmiss the whole sheet
            dismissTop(stack.push())
        } else {            // on a NavigationStack just pop
            dismiss()
        }
    }

    func checkReload(_ stack: CallStack, _ notification: Notification, _ logStr: String = EMPTYSTRING) {
        if let transition: TransactionTransition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
            if transition.transactionId == transactionId {       // is the transition for THIS transaction?
                let newMajor = transition.newTxState.major
                let message = stack.peek()?.message ?? "?"
                if newMajor == .deleted {
                    symLog.log("newState: \(newMajor), show 'deleted', for: \(message)")
                    let error = transition.errorInfo ??
                        TalerErrorDetail(code: 7049,  // WALLET_MERCHANT_ORDER_NOT_FOUND
                                         when: .now(),
                                         hint: "Transaction has been deleted")
                    model.setError(WalletBackendError.walletCoreError(error))
                } else {
                    Task { // runs on MainActor
                           // flush the screen first, then reload
                        withAnimation { talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
                        if newMajor != .none {              // don't reload after delete
                            symLog.log("newState: \(newMajor), reloading transaction, for: \(message)")
                            await loadTransaction()
                        }
                    }
                }
            }
        } else { // Yikes - should never happen
// TODO:      logger.warning("Can't get notification.userInfo as TransactionTransition")
            symLog.log(notification.userInfo as Any)
        }
    }

    func localizedState(_ txState: TransactionState) -> String {
        let major = txState.major
        if major != .failed {
            if let minorState = txState.minor {
                if developerMode { return minorState.localizedDbgState }
//                if talerTX.isPayment {
//                  return String(localized: "Payment", comment: "TxMajorState heading")
//                }
                return minorState.localizedState ?? major.localizedState
            }
        }
        return major.localizedState
    }

    @ViewBuilder
    func dateAndStatus(_ common: TransactionCommon) -> some View {
        let (dateString, date) = TalerDater.dateString(common.timestamp, minimalistic)
        let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
        Text(dateString)
            .talerFont(.body)
            .accessibilityLabel(a11yDate)
            .foregroundColor(WalletColors().secondary2(colorScheme, colorSchemeContrast))
            .id(topID)
        let state = localizedState(common.txState)
        let statusT = Text(state)
            .multilineTextAlignment(.trailing)
        let imageT = Text(common.type.icon())
            .accessibilityHidden(true)
        HStack(alignment: .center, spacing: HSPACING) {
            imageT
            Spacer(minLength: 0)
            statusT
        }   // TODO: a11y for tx icon
        if developerMode {
            if !jsonTransaction.isEmpty {
                CopyButton(jsonTransaction, title: "Copy JSON")
            }
        }
    }

    @ViewBuilder
    func suspendResume(_ common: TransactionCommon) -> some View {
        if talerTX.isSuspendable {
            TransactionButton(transactionId: common.transactionId,
                                    command: .suspend,
                                    warning: nil,
                                 didExecute: $ignoreThis,
                                     action: model.suspendTransaction)
            .listRowSeparator(.hidden)
        }
        if talerTX.isResumable {
            TransactionButton(transactionId: common.transactionId,
                                    command: .resume,
                                    warning: nil,
                                 didExecute: $ignoreThis,
                                     action: model.resumeTransaction)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    func abortFailDelete(_ common: TransactionCommon) -> some View {
        if talerTX.isAbortable {
            let warning = String(localized: "Are you sure you want to abort this transaction?")
            TransactionButton(transactionId: common.transactionId,
                                    command: .abort,
                                    warning: warning,
                                 didExecute: $ignoreThis,
                                     action: model.abortTransaction)
        } // Abort button
        if talerTX.isFailable {
            let warning = String(localized: "Are you sure you want to abandon this transaction?")
            TransactionButton(transactionId: common.transactionId,
                                    command: .fail,
                                    warning: warning,
                                 didExecute: $ignoreThis,
                                     action: model.failTransaction)
        } // Fail button
        if talerTX.isDeleteable {
            let warning = String(localized: "Are you sure you want to delete this transaction?")
            TransactionButton(transactionId: common.transactionId,
                                    command: .delete,
                                    warning: warning,
                                 didExecute: $didDelete,
                                     action: model.deleteTransaction)
            .onChange(of: didDelete) { wasDeleted in
                if wasDeleted {
                    symLog.log("wasDeleted -> dismiss view")
                    dismiss(stack)
                }
            }
        } // Delete button
    }

    var navTitleStr: String {
        let isPaying = talerTX.isPayment && talerTX.isDialog
        let isRepurchase = talerTX.common.isRepurchase
        return talerTX.isDone ? talerTX.localizedTypePast
            : isPaying ? (effective != nil ? String(localized: "Confirm Payment", comment:"pay merchant navTitle")
                                           : String(localized: "Payment not possible", comment:"pay merchant navTitle"))
            : isRepurchase ? String(localized: "Already paid", comment:"repurchase merchant navTitle")
            : talerTX.localizedType
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = talerTX.common
//        let scope = common.scopes.first                                     // might be nil if scopes == []
        let locale = TalerDater.shared.locale
        let isPaying = talerTX.isPayment && talerTX.isDialog
        Group {
          if common.type != .dummy && transactionId == common.transactionId {
            let list = List {
                if developerMode && withActions { suspendResume(common) }
                if !isPaying {
                    Section {
                        VStack(alignment: .leading) {
                            dateAndStatus(common)
                                .listRowSeparator(.hidden)
                                .talerFont(.title)
                        }.overlay {
                            if common.isWorking {
                                RotatingTaler(size: 80, progress: true, once: false,
                                   rotationEnabled: Binding.constant(true))
                            }
                        }
                    }
                }
                if controller.stalledConnection {
                    StalledView()
                } else {
                    TransactionTypeDetail(stack: stack.push(),
                                    transaction: $talerTX,
                                         payNow: $payNow,
                                 selectedChoice: $selectedChoice,
                                          scope: $scope,
                                      effective: $effective,    // return amount for "Pay <amount> now"
                                        hasDone: hasDone)

                    // TODO: Retry Countdown, Retry Now button
//                    if talerTX.isRetryable, let retryAction {
//                        TransactionButton(transactionId: common.transactionId, command: .retry,
//                                          warning: nil, action: abortAction)
//                    } // Retry button
                    if withActions { abortFailDelete(common) }
                }
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
            .background(FullBackground())
            .navigationBarBackButtonHidden(hasDone)
            .interactiveDismissDisabled(hasDone && !isPaying)     // can only use "Done" button to dismiss
            .safeAreaInset(edge: .bottom) {
                let bottomButton = ZStack {
                    if isPaying, case .payment(let paymentTransaction) = talerTX {
                        let details = paymentTransaction.details
                        if let effective, let terms = details.contractTerms {
                            let formatted = effective.formatted(currencyInfo)
                            PaySafeArea(symLog: symLog,
                                         stack: stack.push(),
                                         terms: terms,
                                  amountString: formatted.0,
                                    amountA11y: formatted.1,
                                        payNow: $payNow)
                        } else {
                            Button("Cancel") { dismissTop(stack.push()) }
                                .buttonStyle(TalerButtonStyle(type: .bordered))
                                .padding()
                        } // Cancel
                    } else if let showDone {
                        Button("Done") { dismissTop(stack.push()) }
                            .buttonStyle(TalerButtonStyle(type: showDone))
                            .padding()
                    }
                }
                if #available(iOS 26.0, *) {
                    bottomButton
                        .padding(.horizontal)
                } else {
                    bottomButton
                        .padding()
                }
            }
            .navigationTitle(navTitle ?? navTitleStr)
            .onChange(of: payNow) { payNow2 in
                if payNow2 {
                    Task {
                        await payTransaction()
                        payNow = false   // re-enable "Pay now" if this attempt did not lead to a state transition
                    }
                }
            }
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
                checkReload(stack.push("pendingReady"), notification, "pending ready ==> reload for talerURI")
            }
            .onNotification(.TransactionStateTransition) { notification in
                if !didDelete {
                    checkReload(stack.push("TransactionStateTransition"), notification, "some transition ==> reload")
                }
            }

            if #available(iOS 17.0, *) {
                list
                    .scrollContentBackground(preferredColorScheme == 3 ? .hidden : .visible)
                    .toolbarTitleDisplayMode(.inlineLarge)
            } else {
                list
            }
          } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    symLog.log("task - load transaction")
                    await loadTransaction()
                }
          } // else
        } // Group
        .onChange(of: scope) { newVal in
            if let newVal {
                currencyInfo = controller.info(for: newVal) ?? CurrencyInfo.zero(UNKNOWN)
            }
        }
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONSUMMARY, stack: stack.push())
        }
        .onDisappear {
            symLog.log("onDisappear")
        }
    }
} // TransactionSummaryList
    // MARK: -
    struct KYCbutton: View {
        let kycUrl: String?

        var body: some View {
            if let kycUrl {
                if let destination = URL(string: kycUrl) {
                    LinkButton(destination: destination,
                               hintTitle: String(localized: "You need to pass a legitimization procedure.", comment: "KYC"),
                               buttonTitle: String(localized: "Open legitimization website", comment: "KYC"),
                                  a11yHint: String(localized: "Will go to legitimization website to permit this withdrawal.", comment: "a11y"),
                                     badge: NEEDS_KYC)
                }
            }
        }
    }
    // MARK: -
    struct PendingWithdrawalDetails: View {
        let stack: CallStack
        @Binding var transaction: TalerTransaction
        let details: WithdrawalTransactionDetails

        var body: some View {
            let common = transaction.common
            if transaction.isPendingKYC {
                if let kycUrl = common.kycUrl {
                    KYCbutton(kycUrl: common.kycUrl)
                } else {
                    Text("Legitimization procedure required", comment: "KYC")
                }
            }
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
                                                  a11yHint: String(localized: "Will go to bank website to authorize this withdrawal.", comment: "a11y"),
                                                     badge: CONFIRM_BANK)
                    }   }   }   }
                @unknown default:
                    ErrorView(stack.push(),
                              title: "Unknown withdrawal type",        // should not happen, so no L10N
                            message: withdrawalDetails.toJSON(),
                           copyable: true)
            } // switch
        }
    }
// MARK: -
    struct QRCodeDetails: View {
        var transaction : TalerTransaction
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
                                            scope: transaction.common.scopes.first)
                                            // scopes shouldn't (- but might) be nil!
                    }
                }
            } else if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    Text("from \(baseURL.trimURL)", comment: "baseURL") 
                        .talerFont(.title2)
                        .padding(.bottom)
                }
            }
        }
    }
// MARK: -
#if DEBUG
//struct TransactionSummary_Previews: PreviewProvider {
//    static func deleteTransactionDummy(transactionId: String) async throws {}
//    static func doneActionDummy() {}
//    static var withdrawal = TalerTransaction(incoming: true,
//                                         pending: true,
//                                              id: "some withdrawal ID",
//                                            time: Timestamp(from: 1_666_000_000_000))
//    static var payment = TalerTransaction(incoming: false,
//                                      pending: false,
//                                           id: "some payment ID",
//                                         time: Timestamp(from: 1_666_666_000_000))
//    static func reloadActionDummy(transactionId: String) async -> TalerTransaction { return withdrawal }
//    static var previews: some View {
//        Group {
//            TransactionSummaryV(transaction: withdrawal, reloadAction: reloadActionDummy, doneAction: doneActionDummy)
//            TransactionSummaryV(transaction: payment, reloadAction: reloadActionDummy)
//        }
//    }
//}
#endif
