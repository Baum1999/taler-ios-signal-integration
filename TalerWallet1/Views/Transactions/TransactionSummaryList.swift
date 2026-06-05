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
//    let scope: ScopeInfo?
    let transactionId: String
    @Binding var talerTX: TalerTransaction
    let navTitle: String?
    let hasDone: Bool
    let showDone: TalerButtonStyleType?
    let url: URL?           // the scanned talerURL from PaymentView
    let withActions: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dismiss) var dismiss     // call dismiss() to pop back
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var isCopied: Bool = false
    @State private var ignoreThis: Bool = false
    @State private var didDelete: Bool = false
    @State var jsonTransaction: String = EMPTYSTRING
    @State var viewId = UUID()
    @Namespace var topID

    func loadTransaction() async {
        if let reloadedTransaction = try? await model.getTransactionById(transactionId,
                                                    includeContractTerms: true, viewHandles: false) {
            symLog.log("reloaded \(reloadedTransaction.localizedType): \(reloadedTransaction.common.txState.major)")
            withAnimation { talerTX = reloadedTransaction; viewId = UUID() }      // redraw
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

    @MainActor
    @discardableResult
    func checkDismiss(_ notification: Notification, _ logStr: String = EMPTYSTRING) -> Bool {
        if hasDone {
            if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                if transition.transactionId == talerTX.common.transactionId {       // is the transition for THIS transaction?
                    symLog.log(logStr)
                    if talerTX.common.type.isPayment {
                        checkReload(notification, logStr)
                    } else {
                        dismissTop(stack.push())        // if this view is in a sheet then dissmiss the sheet
                        return true
                    }
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
            dismiss()
        }
    }

    func checkReload(_ notification: Notification, _ logStr: String = EMPTYSTRING) {
        if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
            if transition.transactionId == transactionId {       // is the transition for THIS transaction?
                let newMajor = transition.newTxState.major
                Task { // runs on MainActor
                       // flush the screen first, then reload
                    withAnimation { talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY); viewId = UUID() }
                    symLog.log("newState: \(newMajor), reloading transaction")
                    if newMajor != .none {              // don't reload after delete
                        await loadTransaction()
                    }
                }
            }
        } else { // Yikes - should never happen
// TODO:      logger.warning("Can't get notification.userInfo as TransactionTransition")
            symLog.log(notification.userInfo as Any)
        }
    }

    func localizedState() -> String {
        let txState = talerTX.common.txState
        if talerTX.isPending {
            if let minorState = txState.minor {
                return developerMode ? minorState.localizedDbgState
                                     : minorState.localizedState ?? txState.major.localizedState
            }
        }
        return txState.major.localizedState
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let common = talerTX.common
        let scope = common.scopes.first                                     // might be nil if scopes == []
        let locale = TalerDater.shared.locale
        let (dateString, date) = TalerDater.dateString(common.timestamp, minimalistic)
        let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
        let navTitle2 = talerTX.isDone ? talerTX.localizedTypePast
                                       : talerTX.localizedType
        Group {
          if common.type != .dummy && transactionId == common.transactionId {
            List {
                if withActions && developerMode {
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
                } // Suspend + Resume buttons

                Group {
                    Text(dateString)
                        .talerFont(.body)
                        .accessibilityLabel(a11yDate)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                        .id(topID)
                    let state = localizedState()
                    let statusT = Text(state)
                                    .multilineTextAlignment(.trailing)
                    let imageT = Text(common.type.icon())
                                    .accessibilityHidden(true)
                    HStack(alignment: .center, spacing: HSPACING) {
                        imageT
                        Spacer(minLength: 0)
                        statusT
                    }
                    if developerMode {
                        if !jsonTransaction.isEmpty {
                            CopyButton(textToCopy: jsonTransaction, isCopied: $isCopied, title: "Copy JSON")
                        }
                    }
                }   .listRowSeparator(.hidden)
                    .talerFont(.title)
                    .onAppear {     // doesn't work - view still jumps
//                        scrollView.scrollTo(topID)
//                        withAnimation { scrollView.scrollTo(topID) }
                    }

                TypeDetail(stack: stack.push(),
                           scope: scope,
                     transaction: $talerTX,
                         hasDone: hasDone)

                // TODO: Retry Countdown, Retry Now button
//                if talerTX.isRetryable, let retryAction {
//                    TransactionButton(transactionId: common.transactionId, command: .retry,
//                                      warning: nil, action: abortAction)
//                } // Retry button
                if withActions {
                    if talerTX.isAbortable {
                        TransactionButton(transactionId: common.transactionId,
                                                command: .abort,
                                                warning: String(localized: "Are you sure you want to abort this transaction?"),
                                             didExecute: $ignoreThis,
                                                 action: model.abortTransaction)
                    } // Abort button
                    if talerTX.isFailable {
                        TransactionButton(transactionId: common.transactionId,
                                                command: .fail,
                                                warning: String(localized: "Are you sure you want to abandon this transaction?"),
                                             didExecute: $ignoreThis,
                                                 action: model.failTransaction)
                    } // Fail button
                    if talerTX.isDeleteable {
                        TransactionButton(transactionId: common.transactionId,
                                                command: .delete,
                                                warning: String(localized: "Are you sure you want to delete this transaction?"),
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
            }.id(viewId)    // change viewId to enforce a draw update
            .listStyle(myListStyle.style).anyView
            .navigationBarBackButtonHidden(hasDone)
            .interactiveDismissDisabled(hasDone)           // can only use "Done" button to dismiss
            .safeAreaInset(edge: .bottom) {
                if let showDone {
                    Button("Done") { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: showDone))
                        .padding(.horizontal)
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
                checkReload(notification, "pending ready ==> reload for talerURI")
            }
            .onNotification(.TransactionStateTransition) { notification in
                if !didDelete {
                    checkReload(notification, "some transition ==> reload")
                }
            }
            .navigationTitle(navTitle ?? navTitle2)
          } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    symLog.log("task - load transaction")
                    await loadTransaction()
                }
          } // else
        } // Group
        .onAppear {
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONSUMMARY, stack: stack.push())
        }
        .onDisappear {
            symLog.log("onDisappear")
        }
    }
    // MARK: -
    struct MerchantHeader: View {
        let terms: MerchantContractTerms?

        var body: some View {
            if let terms {
                Section {
                    Text(terms.summary)
                        .talerFont(.title3)
                } header: {
                    HStack {
                        Spacer()
                        VStack(alignment: .center) {
                            let imageName = if #available(iOS 17.0, *) { MERCHANT17 } else { MERCHANT14 }
                            Image(systemName: imageName)
                                .resizable()
                                .frame(width: 44, height: 44)
                            let merchant = terms.merchant.name
                            Text(merchant)
                                .talerFont(.title3)
                        }.foregroundStyle(Color(.primary))
                        Spacer()
                    }
                }
            }
        }
    }
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
    struct KYCauth: View {
        let stack: CallStack
        let common: TransactionCommon

        @AppStorage("minimalistic") var minimalistic: Bool = false
        @State private var accountID = 0
        @State private var listID = UUID()

        func redraw(_ newAccount: Int) -> Void {
            if newAccount != accountID {
                accountID = newAccount
                withAnimation { listID = UUID() }
            }
        }

        func validDetails(_ paytoUris: [String]) -> [ExchangeAccountDetails] {
            var details: [ExchangeAccountDetails] = []
            for paytoUri in paytoUris {
                let payTo = PayTo(paytoUri)
                let amount = common.kycAuthTransferInfo?.amount
                let detail = ExchangeAccountDetails(status: "ok",
                                                  paytoUri: paytoUri,
                                            transferAmount: amount,
                                                     scope: common.scopes[0])
                details.append(detail)
            }
            return details
        }

        var body: some View {
            if let info = common.kycAuthTransferInfo {
                let debitPayTo = PayTo(info.debitPaytoUri)
                let amount = info.amount
                let amountStr = amount.formatted(specs: nil,
                                            isNegative: false,
                                                 scope: common.scopes[0])
                let amountValue = amount.valueStr
                let creditPaytoUris = info.creditPaytoUris
                let validDetails = validDetails(creditPaytoUris)
                if !validDetails.isEmpty {
                    let countPaytos = creditPaytoUris.count
                    let account = validDetails[accountID]

                    Text("You need to prove having control over the bank account for the deposit.")
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                        .multilineTextAlignment(.leading)                   // otherwise
                        .listRowSeparator(.hidden)

                    if countPaytos > 1 {
                        if countPaytos > 3 { // too many for SegmentControl
                            AccountPicker(title: String(localized: "Bank"),
                                          value: $accountID,
                                 accountDetails: validDetails,
                                         action: redraw)
                            .listRowSeparator(.hidden)
                            .pickerStyle(.menu)
                        } else {
                            SegmentControl(value: $accountID,
                                  accountDetails: validDetails,
                                          action: redraw)
                                .listRowSeparator(.hidden)
                        }
                    } else if let creditPaytoUri = creditPaytoUris.first {
                        if let bankName = account.bankLabel {
                            Text(bankName + ":   " + amountStr.0)
                                .accessibilityLabel(bankName + ":   " + amountStr.1)
//                      } else {
//                          Text(amountStr)
                        }
                    }
                    let payto = PayTo(account.paytoUri)
                    if let receiverStr = payto.receiver {
                        let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                        reservePub: info.accountPub,
                                                       receiverStr: receiverStr,
                                                       receiverZip: payto.postalCode,
                                                      receiverTown: payto.town,
                                                              iban: payto.iban,
                                                            cyclos: payto.cyclos ?? EMPTYSTRING,
                                                            xTaler: payto.xTaler ?? EMPTYSTRING,
                                                       amountValue: amountValue,
                                                         amountStr: amountStr,
                                                         obtainStr: nil,        // only for withdrawal
                                                         debitIBAN: debitPayTo.iban,
                                                           account: account)
                        NavigationLink(destination: wireDetails) {
                            Text(minimalistic ? "Instructions"
                                              : "Wire transfer instructions")
                            .talerFont(.title3)
                        }
                    }
                }
            }
        } // body
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
                            message: withdrawalDetails.type.rawValue,
                           copyable: true) {
                        dismissTop(stack.push())
                    }
            } // switch
        }
    }
    // MARK: -
    struct TypeDetail: View {
        let stack: CallStack
        let scope: ScopeInfo?
        @Binding var transaction: TalerTransaction
        let hasDone: Bool
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var colorSchemeContrast
        @AppStorage("minimalistic") var minimalistic: Bool = false
        @State private var rotationEnabled = true
        @State private var ignoreAccept: Bool = false         // accept could be set by OIM to trigger accept
        @State private var isCopied: Bool = false

        func refreshFee(input: Amount, output: Amount) -> Amount? {
            do {
                let fee = try input - output
                return fee
            } catch {
                
            }
            return nil
        }

        func abortedHint(_ delay: Duration?) -> String? {
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
            let dialog = transaction.isDialog
            Group {
                switch transaction {
                    case .dummy(_): Group {
                        let title = EMPTYSTRING
                        Text(title)
                            .talerFont(.body)
                        RotatingTaler(size: 100, progress: true, once: false, rotationEnabled: $rotationEnabled)
                            .frame(maxWidth: .infinity, alignment: .center)
                            // has its own accessibilityLabel
                    }
                    case .withdrawal(let withdrawalTransaction): Group {
                        let details = withdrawalTransaction.details
                        if common.isAborted && details.withdrawalDetails.type == .manual {
                            if let dayStr = abortedHint(details.withdrawalDetails.reserveClosingDelay) {
                                Text("The withdrawal was aborted.\nIf you have already sent money to the payment service, it will wire it back in \(dayStr) days.")
                                    .talerFont(.callout)
                            }
                        }
                        if pending {
                            PendingWithdrawalDetails(stack: stack.push(),
                                               transaction: $transaction,
                                                   details: details)
                        } // ManualDetails or Confirm now (with bank)
                        ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Chosen:", comment: "mini"),
                                       topTitle: String(localized: "Chosen amount to withdraw:"),
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: true,
                                          large: false,
                                        summary: nil)
                    }
                    case .deposit(let depositTransaction): Group {
                        if transaction.common.isPendingKYCauth {
                            KYCauth(stack: stack.push(), common: common)
                        } else if transaction.isPendingKYC {
                            KYCbutton(kycUrl: common.kycUrl)
                        }
                        ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Deposit:", comment: "mini"),
                                       topTitle: String(localized: "Amount to deposit:"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: false,
                                          large: true,
                                        summary: nil)
                    }
                    case .payment(let paymentTransaction): Group {
                        let details = paymentTransaction.details
                        if common.isDialog {        // show payment confirmation dialog
                            let firstScope = common.scopes.first
                            PaymentView2(stack: stack.push(),
                                          paid: false,
                                           raw: common.amountRaw,
                                     effective: common.amountEffective,
                                    firstScope: firstScope,
                                       baseURL: nil,
                                       summary: details.info?.summary,
                                      products: details.info?.products,
                                balanceDetails: nil)

                        } else {                    // show finished payment
                            TransactionPayDetailV(paymentTx: paymentTransaction)
                            ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Price:", comment: "mini"),
                                       topTitle: String(localized: "Price (net):"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: false,
                                          large: true,
                                        summary: details.info?.summary)
                        }
                    }
                    case .refund(let refundTransaction): Group {
                        let details = refundTransaction.details                 // TODO: more details, details.info?.merchant.name
                        ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Refunded:", comment: "mini"),
                                       topTitle: String(localized: "Refunded amount:"),
                                        baseURL: nil,               // TODO: baseURL
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: true,
                                          large: true,
                                        summary: details.info?.summary)
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
                                       title: minimalistic ? "Refreshed:" : "Refreshed amount:",
                                      amount: input,
                                       scope: scope,
                                  isNegative: nil,
                                       color: labelColor,
                                       large: true)
                            if let fee = refreshFee(input: input, output: details.refreshOutputAmount) {
                                AmountRowV(stack: stack.push(),
                                           title: minimalistic ? "Fee:" : "Refreshed fee:",
                                          amount: fee,
                                           scope: scope,
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
                                    CopyButton(textToCopy: errorStr, isCopied: $isCopied, vertical: true)
                                        .accessibilityLabel(Text("Copy the error", comment: "a11y"))
                                        .disabled(false)
                                }
                            }
                        }
                    }

                    case .peer2peer(let p2pTransaction): Group {
                        let details = p2pTransaction.details
                        if transaction.isPendingKYC {
                            KYCbutton(kycUrl: common.kycUrl)
                        }
                        if !transaction.isDone {
                            ExpiresView(expiration: details.info.expiration)
                        }
                        if transaction.isRcvCoins && common.isDialog {
                            PeerPushCreditView(stack: stack.push(),
                                                 raw: common.amountRaw,
                                           effective: common.amountEffective,
                                               scope: scope,
                                             summary: details.info.summary)
                            PeerPushCreditAccept(stack: stack.push(), url: nil,
                                         transactionId: common.transactionId,
                                                accept: $ignoreAccept)
                        } else if transaction.isPayInvoice && common.isDialog {
                            PeerPullDebitView(stack: stack.push(),
                                                raw: common.amountRaw,
                                          effective: common.amountEffective,
                                              scope: scope,
                                            summary: details.info.summary)
                            PeerPullDebitConfirm(stack: stack.push(), url: nil,
                                         transactionId: common.transactionId)
                        } else {
                        // TODO: isSendCoins should show QR only while not yet expired  - either set timer or wallet-core should do so and send a state-changed notification
                            // TODO: details.info.summary
                        if pending {
                            if transaction.isPendingReady {
                                QRCodeDetails(transaction: transaction)
                                if hasDone {
                                    Text("QR code and link can also be scanned or copied / shared from Transactions later.")
                                        .multilineTextAlignment(.leading)
                                        .talerFont(.subheadline)
//                                        .padding(.top)
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
                                          scope: scope,
                                         common: common,
                                      topAbbrev: localizedType + colon,
                                       topTitle: localizedType + colon,
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,         // TODO: noFees
                                  feeIsNegative: true,
                                          large: false,
                                        summary: details.info.summary)
                        } // else
                    } // p2p

                    case .recoup(let recoupTransaction): Group {
                        let details = recoupTransaction.details     // TODO: details.recoupReason
                        ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Recoup:", comment: "mini"),
                                       topTitle: String(localized: "Recoup:"),
                                        baseURL: nil,               // TODO: baseURL, noFees
                                         noFees: nil,
                                  feeIsNegative: nil,
                                          large: true,
                                        summary: details.recoupReason)
                    }
                    case .denomLoss(let denomLossTransaction): Group {
                        let details = denomLossTransaction.details              // TODO: more details, details.lossEventType.rawValue
                        ThreeAmountsSheet(stack: stack.push(),
                                          scope: scope,
                                         common: common,
                                      topAbbrev: String(localized: "Lost:", comment: "mini"),
                                       topTitle: String(localized: "Money lost:"),
                                        baseURL: details.exchangeBaseUrl,
                                         noFees: nil,               // TODO: noFees
                                  feeIsNegative: nil,
                                          large: true,
                                        summary: details.lossEventType.rawValue)
                    }
                } // switch
            } // Group
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
} // TransactionSummaryV
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
