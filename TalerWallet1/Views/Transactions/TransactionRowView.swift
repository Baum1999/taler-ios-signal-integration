/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import taler_swift
import SymLog

struct TransactionTimeline: View {
    let timestamp: Timestamp
    let textColor: Color
    let layout: Int
    let maxLines: Int

    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let (dateString, date) = TalerDater.dateString(timestamp, minimalistic, relative: true)
            TruncationDetectingText(dateString, maxLines: maxLines, layout: layout, index: 1)
                .foregroundColor(textColor)
                .talerFont(.callout)
        }
    }
}

@MainActor
struct TransactionRowView: View {
    let stack: CallStack
    private let symLog = SymLogV(0)
    let logger: Logger?
    let scope: ScopeInfo
    let transaction : TalerTransaction

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("debugViews") var debugViews: Bool = false

    @State private var merchantLogo: String? = nil
    @State private var layoutStati0: [Int: Bool] = [:]
    @State private var layoutStati1: [Int: Bool] = [:]

    /// The first layout mode that can display the content without truncation
    private var optimalLayout: Int? {
        let keys0 = layoutStati0.keys.sorted(by: { $0 < $1 })
        let keys1 = layoutStati1.keys.sorted(by: { $0 < $1 })

        for key in keys0 {
            let isTruncated0 = layoutStati0[key] ?? true
            let isTruncated1 = layoutStati1[key] ?? true
            if !isTruncated0 && !isTruncated1 {
                return key
            }
        }
        return keys0.last
    }

    private func isLayoutSelected(_ mode: Int) -> Bool {
        return optimalLayout == mode
    }

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (contentWidth + valueWidth + 40)
    }

    func topString(forA11y: Bool = false) -> String? {
        switch transaction {
            case .payment(let paymentTransaction):
                return paymentTransaction.details.info?.merchant.name ?? "..."
            case .peer2peer(let p2pTransaction):
                return p2pTransaction.details.info.summary
            default:
                let result = transaction.isDone ? transaction.localizedTypePast
                                                : transaction.localizedType
                return forA11y ? result
                : minimalistic ? nil
                               : result
        }
    }
#if TALER_NIGHTLY
    var red: Color { developerMode && debugViews ? Color.red : Color.clear }
    var green: Color { developerMode && debugViews ? Color.green : Color.clear }
    var blue: Color { developerMode && debugViews ? Color.blue : Color.clear }
    var orange: Color { developerMode && debugViews ? Color.orange : Color.clear }
    var purple: Color { developerMode && debugViews ? Color.purple : Color.clear }
#endif

    var common: TransactionCommon { transaction.common }
    var done: Bool { transaction.isDone }
    var isWorking: Bool { transaction.isWorking }
    var pending: Bool { transaction.isPending || common.isFinalizing }
    var needsKYC: Bool { transaction.isPendingKYC || transaction.isPendingKYCauth }
    var doneOrPending: Bool { done || pending }
    var donePendingDialog: Bool { doneOrPending || transaction.isDialog }
    var shouldConfirm: Bool { transaction.shouldConfirm }
    var isZero: Bool { common.amountEffective.isZero }
    var incoming: Bool { common.isIncoming }
    var refreshZero: Bool { common.type.isRefresh && isZero }

    func textColor() -> Color {
        let isDark = colorScheme == .dark
        let increasedContrast = colorSchemeContrast == .increased
        return doneOrPending ? .primary
                    : isDark ? .secondary
         : increasedContrast ? Color(.darkGray)
                             : .secondary  // Color(.tertiaryLabel)
        }
    var strikeColor: Color? { donePendingDialog ? nil : WalletColors().negative }
    func foreColor(_ textColor: Color) -> Color {
        refreshZero ? textColor
          : pending ? WalletColors().pendingColor(incoming)
             : done ? WalletColors().transactionColor(incoming)
                    : WalletColors().uncompletedColor
    }
    func for2Color(_ textColor: Color) -> Color {
        let primaryAccent = WalletColors().primaryAccent
        return refreshZero ? textColor
           : doneOrPending ? (incoming ? primaryAccent : textColor)
                           : WalletColors().uncompletedColor
    }
    func iconBadge(_ foreColor: Color) -> TransactionIconBadge {
        TransactionIconBadge(type: common.type,
                        foreColor: foreColor,
                             done: done,
                         incoming: incoming,
                    shouldConfirm: shouldConfirm && pending,
                         needsKYC: needsKYC && pending,
                      imageBase64: merchantLogo)
    }
    var topA11y: String { topString(forA11y: true)! }
    var a11yLabel: String { donePendingDialog ? topA11y
                                              : topA11y +  String(localized: ", canceled", comment: "a11y")
        }
    var amountV: AmountV { AmountV(scope, transaction.amount(),
                              isNegative: isZero ? nil : !incoming,
                           strikethrough: !donePendingDialog) }

#if TALER_NIGHTLY
    @ViewBuilder func layout0(_ topString: String?, _ textColor: Color, _ for2Color: Color) -> some View {
        // orange amount right centered, top & bottom left
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let topString {
                    TruncationDetectingText(topString,
                                   maxLines: 1,
                                     layout: 0,
                                strikeColor: strikeColor)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(textColor)
                        .talerFont(.headline)
                        .padding(.bottom, -2.0)
                        .overlay { Color.clear.border(red) }
                }
                TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 0, maxLines: 1)
                    .overlay { Color.clear.border(green) }
            }
//           .border(orange)
            Spacer(minLength: 4)
            amountV
                .foregroundColor(for2Color)
                .background(orange.opacity(0.2))
        }
    } // layout0
#endif

#if TALER_NIGHTLY
    @ViewBuilder func layout1(_ topString: String?, _ textColor: Color, _ for2Color: Color) -> some View {
        // top full-width, bottom & green amount below
        VStack(alignment: .leading, spacing: 2) {
            if let topString {
                TruncationDetectingText(topString,
                               maxLines: 10,
                                 layout: 1,
                            strikeColor: strikeColor)
                    .accessibilityLabel(a11yLabel)
                    .foregroundColor(textColor)
                    .talerFont(.headline)
                    .padding(.bottom, -2.0)
                    .overlay { Color.clear.border(red) }
            }
            // spacing + Spacer will result in twice the spacing
//            HStack(spacing: 6) {        // will thrash if set to anything smaller than 5
            HStack(spacing: 0) {        // will thrash if set to anything smaller than 5
                                        // onChange(of: CGSize) action tried to update multiple times per frame.
                TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 1, maxLines: 1)
                    .overlay { Color.clear.border(green) }
                Spacer(minLength: 4)    // will thrash if set to 2 or more
                amountV
                    .foregroundColor(for2Color)
                    .background(green.opacity(0.2))
            }
        }
    } // layout1
#endif

#if TALER_NIGHTLY
    @ViewBuilder func layout2(_ topString: String?, _ textColor: Color, _ for2Color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let timeline = TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 2, maxLines: 10)
                .overlay { Color.clear.border(green) }
            if let topString {
                // top & red amount, bottom below
                HStack {
                    TruncationDetectingText(topString,
                                   maxLines: 1,
                                     layout: 2,
                                strikeColor: strikeColor)
                        .accessibilityLabel(a11yLabel)
                        .foregroundColor(textColor)
                        .talerFont(.headline)
                        .padding(.bottom, -2.0)
//                      .overlay { Color.clear.border(red) }
                    Spacer(minLength: 6)
                    amountV
                        .foregroundColor(for2Color)
                        .background(red.opacity(0.2))
                }
                timeline
            } else {        // no top, bottom & purple amount
                HStack {
                    timeline
                    Spacer(minLength: 6)
                    amountV
                        .foregroundColor(for2Color)
                        .background(purple.opacity(0.2))
                }
            }
        }
    } // layout2
#endif

    @ViewBuilder func layout3(_ topString: String?, _ textColor: Color, _ for2Color: Color) -> some View {
        // top full-width, blue amount trailing, bottom full-width
        let row = VStack(alignment: .leading, spacing: 2) {
            if let topString {
                TruncationDetectingText(topString,
                               maxLines: 10,
                                 layout: 3,
                            strikeColor: strikeColor)
                    .accessibilityLabel(a11yLabel)
                    .foregroundColor(textColor)
//                  .strikethrough(!donePendingDialog, color: WalletColors().negative)
                    .talerFont(.headline)
//                  .fontWeight(.medium)      iOS 16 only
                    .padding(.bottom, -2.0)
#if TALER_NIGHTLY
                    .overlay { Color.clear.border(red) }
#endif
            }
//          HStack(spacing: -4) {
            HStack {
                Spacer(minLength: 0)
                amountV
                    .foregroundColor(for2Color)
#if TALER_NIGHTLY
                    .background(blue.opacity(0.2))
#endif
            }
            TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 3, maxLines: 10)
#if TALER_NIGHTLY
                .overlay { Color.clear.border(green) }
#endif
        }
        ZStack {
            row
            if isWorking {
                RotatingTaler(size: 80, progress: true, once: false,
                   rotationEnabled: Binding.constant(true))
            }
        }
    } // layout3

#if TALER_NIGHTLY
    @ViewBuilder func layout(_ topString: String?) -> some View {
        let textColor = textColor()
        let for2Color = for2Color(textColor)
        ZStack {
            layout0(topString, textColor, for2Color)
                .layoutPriority(isLayoutSelected(0) ? 2 : 1)
                .opacity(isLayoutSelected(0) ? 1 : 0)
            layout1(topString, textColor, for2Color)
                .layoutPriority(isLayoutSelected(1) ? 2 : 1)
                .opacity(isLayoutSelected(1) ? 1 : 0)
            layout2(topString, textColor, for2Color)
                .layoutPriority(isLayoutSelected(2) ? 2 : 1)
                .opacity(isLayoutSelected(2) ? 1 : 0)
            layout3(topString, textColor, for2Color)
                .layoutPriority(isLayoutSelected(3) ? 2 : 1)
                .opacity(isLayoutSelected(3) ? 1 : 0)
        }
        .onPreferenceChange(LayoutTruncationStatus0.self) { stati in    // top string
//          logger?.log("LayoutTruncationStatus0")
            DispatchQueue.main.async {
                self.layoutStati0 = stati
            }
        }
        .onPreferenceChange(LayoutTruncationStatus1.self) { stati in    // Timeline
//          logger?.log("LayoutTruncationStatus1")
            DispatchQueue.main.async {
                self.layoutStati1 = stati
            }
        }
    }
#endif

    func merchantLogo(talerTx: TalerTransaction) -> String? {
        switch talerTx {
            case .payment(let paymentTransaction):
                if let terms = paymentTransaction.details.contractTerms {
                    return terms.merchant.logo
                }
            default: break
        }
        return nil
    }
    private func viewDidLoad() async {
        if transaction.isPayment {
            let txId = transaction.id
            if merchantLogo == nil {
                symLog.log("loading merchantLogo for \(txId)")
                if let fullTx = try? await model.getTransactionById(txId, includeContractTerms: true) {
                    if let logo = merchantLogo(talerTx: fullTx) {
                        symLog("found terms.merchant.logo for \(txId)")
                        merchantLogo = logo
                    } else {
                        symLog("no logo")
                    }
                } else {
                    symLog.log("loading \(txId) failed")
                }
            } else {
                symLog.log("There is already a merchantLogo for \(txId)")
            }
        }
    }

    var body: some View {
#if DEBUG
//        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
//        let details = transaction.detailsToShow()
//        let keys = details.keys
        let topString = topString()
        let textColor = textColor()
        let foreColor = foreColor(textColor)
        let iconBadge = iconBadge(foreColor)
        HStack {
            iconBadge.talerFont(.title2)
#if TALER_NIGHTLY
            if #available(iOS 18.0, *) {
                layout(topString)
            } else {
                let for2Color = for2Color(textColor)
                layout3(topString, textColor, for2Color)
            }
#else   // Stop using dynamic layouts for Taler Wallet and GNU Taler because of flickering
            let for2Color = for2Color(textColor)
            layout3(topString, textColor, for2Color)
#endif
        }
            .accessibilityElement(children: .combine)
            .accessibilityValue(!donePendingDialog ? EMPTYSTRING
                                        : needsKYC ? String(localized: ". Legitimization required", comment: "a11y")
                                   : shouldConfirm ? String(localized: ". Needs bank authorization", comment: "a11y")
                                                   : EMPTYSTRING)
            .accessibilityHint(String(localized: "Will go to detail view.", comment: "a11y"))
            .task {
                await viewDidLoad()
            }
    }
}
// MARK: -
#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var withdrawal = TalerTransaction(incoming: true,
                                         pending: false,
                                              id: "some withdrawal ID",
                                            time: Timestamp(from: 1_666_000_000_000))
    static var payment = TalerTransaction(incoming: false,
                                      pending: false,
                                           id: "some payment ID",
                                         time: Timestamp(from: 1_666_666_000_000))
    @MainActor
    struct StateContainer: View {
        @State private var previewD = CurrencyInfo.zero(DEMOCURRENCY)
        @State private var previewT = CurrencyInfo.zero(TESTCURRENCY)

        var body: some View {
            let scope = ScopeInfo.zero(DEMOCURRENCY)
            List {
                TransactionRowView(stack: CallStack(), logger: nil, scope: scope, transaction: withdrawal)
                TransactionRowView(stack: CallStack(), logger: nil, scope: scope, transaction: payment)
            }
        }
    }

    static var previews: some View {
        StateContainer()
//            .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
// MARK: -
extension TalerTransaction {             // for PreViews
    init(incoming: Bool, pending: Bool, id: String, time: Timestamp) {
        let txState = TransactionState(major: pending ? TransactionMajorState.pending
                                                      : TransactionMajorState.done)
        let raw = Amount(currency: LONGCURRENCY, cent: 500)
        let eff = Amount(currency: LONGCURRENCY, cent: incoming ? 480 : 520)
        let common = TransactionCommon(type: incoming ? .withdrawal : .payment,
                              transactionId: id,
                                  timestamp: time,
                                     scopes: [],
                                    txState: txState,
                                  txActions: [.abort],
                                  amountRaw: raw,
                            amountEffective: eff)
        if incoming {
            // if pending then manual else bank-integrated
            let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company&amount=KUDOS%3A9.99&message=Taler+Withdrawal+J41FQPJGAP1BED1SFSXHC989EN8HRDYAHK688MQ228H6SKBMV0AG"
            let withdrawalDetails = WithdrawalDetails(type: pending ? WithdrawalDetails.WithdrawalType.manual
                                                                    : WithdrawalDetails.WithdrawalType.bankIntegrated,
                                                reservePub: "PuBlIc_KeY_oF_tHe_ReSeRvE",
                                            reserveIsReady: false,
                                                 confirmed: false)
            let wDetails = WithdrawalTransactionDetails(exchangeBaseUrl: DEMOEXCHANGE,
                                                      withdrawalDetails: withdrawalDetails)
            self = .withdrawal(WithdrawalTransaction(common: common, details: wDetails))
        } else {
            let merchant = MerchantInfo(name: "some random shop")
            let info = OrderShortInfo(orderId: "some order ID",
                                     merchant: merchant,
                                      summary: "some product summary",
                                     products: [])
            let pDetails = PaymentTransactionDetails(info: info,
                                           totalRefundRaw: Amount(currency: LONGCURRENCY, cent: 300),
                                     totalRefundEffective: Amount(currency: LONGCURRENCY, cent: 280),
                                                  refunds: [],
                                        refundQueryActive: false,
                                            contractTerms: nil,
                                              choiceIndex: nil,
                                  repurchaseTransactionId: nil,
                                              abortReason: nil)
            self = .payment(PaymentTransaction(common: common, details: pDetails))
        }
    }
}
#endif
