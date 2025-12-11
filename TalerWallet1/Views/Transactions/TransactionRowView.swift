/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
    private let symLog = SymLogV(0)
    let logger: Logger?
    let scope: ScopeInfo
    let transaction : TalerTransaction

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

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
                return paymentTransaction.details.info.merchant.name
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

    func amount() -> Amount {
        switch transaction {
            case .refresh(let refreshTransaction):
                let details = refreshTransaction.details
                return details.refreshInputAmount
            default:
                let common = transaction.common
                let eff = common.amountEffective
                if !eff.isZero { return eff }
                return common.amountRaw
        }
    }

    var body: some View {
#if DEBUG
//        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let pending = transaction.isPending || transaction.common.isFinalizing
        let needsKYC = transaction.isPendingKYC || transaction.isPendingKYCauth
        let shouldConfirm = transaction.shouldConfirm
        let done = transaction.isDone
        let doneOrPending = done || pending
        let increasedContrast = colorSchemeContrast == .increased
        let details = transaction.detailsToShow()
        let keys = details.keys
        let common = transaction.common
        let isZero = common.amountEffective.isZero
        let incoming = common.isIncoming
        let textColor = doneOrPending ? .primary
               : colorScheme == .dark ? .secondary
                  : increasedContrast ? Color(.darkGray)
                                      : .secondary  // Color(.tertiaryLabel)
        let refreshZero = common.type.isRefresh && isZero
        let foreColor = refreshZero ? textColor
                          : pending ? WalletColors().pendingColor(incoming)
                             : done ? WalletColors().transactionColor(incoming)
                                    : WalletColors().uncompletedColor
        let for2Color = refreshZero ? textColor
                : (pending || done) ? (incoming ? .accentColor : textColor)
                                    : WalletColors().uncompletedColor

        let iconBadge = TransactionIconBadge(type: common.type, foreColor: foreColor,
                                             done: done, incoming: incoming,
                                    shouldConfirm: shouldConfirm && pending,
                                         needsKYC: needsKYC && pending)
        let amountV = AmountV(scope, amount(), isNegative: isZero ? nil : !incoming,
                              strikethrough: !doneOrPending)
                        .foregroundColor(for2Color)
        let topA11y = topString(forA11y: true)!
        let topString = topString()
        let strikeColor = doneOrPending ? nil : WalletColors().negative
        let a11yLabel = doneOrPending ? topA11y
                                      : topA11y +  String(localized: ", canceled", comment: "a11y")

#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
        let purple = debug ? Color.purple : Color.clear
#endif

        let layout0 = HStack(spacing: 4) {                                      // amount right centered, top & bottom left
                VStack(alignment: .leading, spacing: 2) {
                    if let topString {
                        TruncationDetectingText(topString,
                                       maxLines: 1,
                                         layout: 0,
                                    strikeColor: strikeColor)
                        .foregroundColor(textColor)
                        .talerFont(.headline)
                        .padding(.bottom, -2.0)
#if DEBUG
                        .border(red)
#endif
                        .accessibilityLabel(a11yLabel)
                    }
                    TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 0, maxLines: 1)
#if DEBUG
                        .border(green)
#endif
                }
//                .border(orange)
                Spacer(minLength: 0)
                amountV //.frame(maxWidth: .infinity, alignment: .trailing)
#if DEBUG
                .background(orange.opacity(0.2))
#endif
        }

        let layout1 = VStack(alignment: .leading, spacing: 2) {                 // top full-width, bottom & amount below
            if let topString {
                TruncationDetectingText(topString,
                               maxLines: 10,
                                 layout: 1,
                            strikeColor: strikeColor)
                .foregroundColor(textColor)
                .talerFont(.headline)
                .padding(.bottom, -2.0)
#if DEBUG
                .border(red)
#endif
                .accessibilityLabel(a11yLabel)
            }
            HStack(spacing: 6) {
                TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 1, maxLines: 1)
#if DEBUG
                    .border(green)
#endif
                Spacer(minLength: 0)
                amountV
#if DEBUG
                    .background(green.opacity(0.2))
#endif
            }
        }

        let layout2 = VStack(alignment: .leading, spacing: 0) {
            if let topString {   // top & amount, bottom below
                HStack(spacing: 6) {
                    TruncationDetectingText(topString,
                                   maxLines: 1,
                                     layout: 2,
                                strikeColor: strikeColor)
                    .foregroundColor(textColor)
                    .talerFont(.headline)
                    .padding(.bottom, -2.0)
                    .accessibilityLabel(a11yLabel)
#if DEBUG
//                    .border(red)
#endif
                    Spacer(minLength: 2)
                    amountV
#if DEBUG
                        .background(red.opacity(0.2))
#endif
                }
                TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 2, maxLines: 10)
#if DEBUG
                    .border(green)
#endif
            } else {        // no top, bottom & amount
                HStack(spacing: 6) {
                    TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 2, maxLines: 10)
#if DEBUG
                        .border(green)
#endif
                    Spacer(minLength: 2)
                    amountV
#if DEBUG
                        .background(purple.opacity(0.2))
#endif
                }
            }
        }

        let layout3 = VStack(alignment: .leading, spacing: 2) {                 // top full-width, amount trailing, bottom full-width
            if let topString {
                TruncationDetectingText(topString,
                               maxLines: 10,
                                 layout: 3,
                            strikeColor: strikeColor)
                .foregroundColor(textColor)
  //            .strikethrough(!doneOrPending, color: WalletColors().negative)
                .talerFont(.headline)
  //            .fontWeight(.medium)      iOS 16 only
                .padding(.bottom, -2.0)
#if DEBUG
                .border(red)
#endif
                .accessibilityLabel(a11yLabel)

            }
            HStack(spacing: -4) {
                Spacer(minLength: 0)
                amountV
#if DEBUG
                    .background(blue.opacity(0.2))
#endif
            }
            TransactionTimeline(timestamp: common.timestamp, textColor: textColor, layout: 3, maxLines: 10)
#if DEBUG
                .border(green)
#endif
        }

        HStack {
            iconBadge.talerFont(.title2)
#if DEBUG
                .border(blue)
#endif
            ZStack {
                layout0
                    .layoutPriority(isLayoutSelected(0) ? 2 : 1)
                    .opacity(isLayoutSelected(0) ? 1 : 0)
                layout1
                    .layoutPriority(isLayoutSelected(1) ? 2 : 1)
                    .opacity(isLayoutSelected(1) ? 1 : 0)
                layout2
                    .layoutPriority(isLayoutSelected(2) ? 2 : 1)
                    .opacity(isLayoutSelected(2) ? 1 : 0)
                layout3
                    .layoutPriority(isLayoutSelected(3) ? 2 : 1)
                    .opacity(isLayoutSelected(3) ? 1 : 0)
            }
                .onPreferenceChange(LayoutTruncationStatus0.self) { stati in    // top string
//                    logger?.log("LayoutTruncationStatus0")
                    DispatchQueue.main.async {
                        self.layoutStati0 = stati
                    }
                }
                .onPreferenceChange(LayoutTruncationStatus1.self) { stati in    // Timeline
//                    logger?.log("LayoutTruncationStatus1")
                    DispatchQueue.main.async {
                        self.layoutStati1 = stati
                    }
                }
        }
            .accessibilityElement(children: .combine)
            .accessibilityValue(!doneOrPending ? EMPTYSTRING
                                    : needsKYC ? String(localized: ". Legitimization required", comment: "a11y")
                               : shouldConfirm ? String(localized: ". Needs bank authorization", comment: "a11y")
                                               : EMPTYSTRING)
            .accessibilityHint(String(localized: "Will go to detail view.", comment: "a11y"))
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
                TransactionRowView(logger: nil, scope: scope, transaction: withdrawal)
                TransactionRowView(logger: nil, scope: scope, transaction: payment)
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
            let merchant = Merchant(name: "some random shop")
            let info = OrderShortInfo(orderId: "some order ID",
                                     merchant: merchant,
                                      summary: "some product summary",
                                     products: [])
            let pDetails = PaymentTransactionDetails(info: info,
                                           totalRefundRaw: Amount(currency: LONGCURRENCY, cent: 300),
                                     totalRefundEffective: Amount(currency: LONGCURRENCY, cent: 280),
                                                  refunds: [],
                                        refundQueryActive: false)
            self = .payment(PaymentTransaction(common: common, details: pDetails))
        }
    }
}
#endif
