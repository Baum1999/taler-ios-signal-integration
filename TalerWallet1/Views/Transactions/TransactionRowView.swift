/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct TransactionRowView: View {
    let scope: ScopeInfo
    let transaction : Transaction

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

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
        let pending = transaction.isPending
        let needsKYC = transaction.isPendingKYC
        let shouldConfirm = transaction.shouldConfirm
        let done = transaction.isDone
        let doneOrPending = done || pending
        let increasedContrast = colorSchemeContrast == .increased
        let details = transaction.detailsToShow()
        let keys = details.keys
        let common = transaction.common
        let isZero = common.amountEffective.isZero
        let incoming = common.incoming()
        let textColor = doneOrPending ? .primary
               : colorScheme == .dark ? .secondary
                  : increasedContrast ? Color(.darkGray)
                                      : .secondary  // Color(.tertiaryLabel)
        let refreshZero = common.type.isRefresh && isZero
        let foreColor = refreshZero ? textColor
                          : pending ? WalletColors().pendingColor(incoming)
                             : done ? WalletColors().transactionColor(incoming)
                                    : WalletColors().uncompletedColor

        let iconBadge = TransactionIconBadge(type: common.type, foreColor: foreColor,
                                             done: done, incoming: incoming,
                                    shouldConfirm: shouldConfirm && pending,
                                         needsKYC: needsKYC && pending)
        let amountV = AmountV(scope, amount(), isNegative: isZero ? nil : !incoming,
                              strikethrough: !doneOrPending)
            .foregroundColor(foreColor)

        let topA11y = topString(forA11y: true)
        let topString = topString()
        let centerTop = Text(topString ?? EMPTYSTRING)
            .foregroundColor(textColor)
            .strikethrough(!doneOrPending, color: WalletColors().negative)
            .talerFont(.headline)
//            .fontWeight(.medium)      iOS 16
            .padding(.bottom, -2.0)
            .accessibilityLabel(doneOrPending ? topA11y!
                                              : topA11y! +  String(localized: ", canceled", comment: "VoiceOver"))
        let centerBottom = TimelineView(.everyMinute) { context in
            let (dateString, date) = TalerDater.dateString(common.timestamp, minimalistic, relative: true)
            Text(dateString)
                .foregroundColor(textColor)
                .talerFont(.callout)
        }

#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
#endif

        let layout1 = HStack(spacing: 4) {                                      // amount right centered, top & bottom left
                VStack(alignment: .leading, spacing: 2) {
                    if topString != nil { centerTop }
                    centerBottom
                }
#if DEBUG
                .border(orange)
#endif
            Spacer(minLength: 0)
            amountV //.frame(maxWidth: .infinity, alignment: .trailing)
        }

        let layout2 = VStack(alignment: .leading, spacing: 2) {                 // top full-width, bottom & amount below
            if topString != nil { centerTop }
            HStack(spacing: 6) {
                centerBottom
#if DEBUG
                    .border(green)
#endif
                Spacer(minLength: 0)
                amountV
#if DEBUG
                    .border(red)
#endif
            }
        }

        let layout3 = VStack(alignment: .leading, spacing: 0) {
            if topString != nil {                                               // top & amount, bottom below
                HStack(spacing: 8) {
                    centerTop
                    Spacer(minLength: 2)
                    amountV
                }
                centerBottom
            } else {                                                            // no top, bottom & amount
                HStack(spacing: 8) {
                    centerBottom
                    Spacer(minLength: 2)
                    amountV
                }
            }
        }

        let layout4 = VStack(alignment: .leading, spacing: 2) {                 // top full-width, amount right, bottom full-width
            if topString != nil { centerTop }
            HStack(spacing: -4) {
                Spacer(minLength: 2)
                amountV
#if DEBUG
                    .border(green)
#endif
            }
#if DEBUG
                .border(orange)
#endif
            centerBottom
        }

        HStack {
            iconBadge
#if DEBUG
                .border(blue)
#endif
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    layout1
#if DEBUG
                        .border(green)
#endif
                    layout2
#if DEBUG
                        .border(orange)
#endif
                    layout3
#if DEBUG
                        .border(red)
#endif
                    layout4
#if DEBUG
                        .border(blue)
#endif
                }
            } else { layout4 } // view for iOS 15
        }
            .accessibilityElement(children: .combine)
            .accessibilityValue(!doneOrPending ? EMPTYSTRING
                                    : needsKYC ? String(localized: ". Needs K Y C")
                               : shouldConfirm ? String(localized: ". Needs bank authorization")
                                               : EMPTYSTRING)
            .accessibilityHint(String(localized: "Will go to detail view."))
    }
}
// MARK: -
#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var withdrawal = Transaction(incoming: true,
                                         pending: false,
                                              id: "some withdrawal ID",
                                            time: Timestamp(from: 1_666_000_000_000))
    static var payment = Transaction(incoming: false,
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
                TransactionRowView(scope: scope, transaction: withdrawal)
                TransactionRowView(scope: scope, transaction: payment)
            }
        }
    }

    static var previews: some View {
        StateContainer()
//            .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
// MARK: -
extension Transaction {             // for PreViews
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
