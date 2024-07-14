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
    let transaction : Transaction

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (contentWidth + valueWidth + 40)
    }

    func topString() -> String {
        switch transaction {
            case .payment(let paymentTransaction):
                return paymentTransaction.details.info.merchant.name
            default:
                return transaction.isDone ? transaction.localizedTypePast
                                          : transaction.localizedType
        }
    }

    var body: some View {
        let common = transaction.common
        let pending = transaction.isPending
        let needsKYC = transaction.isPendingKYC
        let shouldConfirm = transaction.shouldConfirm
        let done = transaction.isDone
        let doneOrPending = done || pending
        let increasedContrast = colorSchemeContrast == .increased
        let details = transaction.detailsToShow()
        let keys = details.keys

        let incoming = common.incoming()
        let textColor = doneOrPending ? .primary
               : colorScheme == .dark ? .secondary
                  : increasedContrast ? Color(.darkGray)
                                      : .secondary  // Color(.tertiaryLabel)
        let refreshZero = common.type.isRefresh && common.amountEffective.isZero
        let foreColor = refreshZero ? textColor
                          : pending ? WalletColors().pendingColor(incoming)
                             : done ? WalletColors().transactionColor(incoming)
                                    : WalletColors().uncompletedColor

        let iconBadge = TransactionIconBadge(type: common.type, foreColor: foreColor,
                                             done: done, incoming: incoming,
                                    shouldConfirm: shouldConfirm, needsKYC: needsKYC)
        let amountV = AmountV(common.amountEffective, isNegative: !incoming)
            .foregroundColor(foreColor)

        let topString = topString()
        let centerTop = Text(topString)
            .foregroundColor(textColor)
            .strikethrough(!doneOrPending, color: .red)
            .talerFont(.headline)
//            .fontWeight(.medium)      iOS 16
            .padding(.bottom, -2.0)
            .accessibilityLabel(doneOrPending ? topString : topString +  String(localized: ", canceled", comment: "VoiceOver"))
        let centerBottom = TimelineView(.everyMinute) { context in
            let (dateString, date) = TalerDater.dateString(from: common.timestamp, relative: true)
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

        let layout1 = HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    centerTop
                    centerBottom
                }
#if DEBUG
                .border(orange)
#endif
            Spacer(minLength: 0)
            amountV //.frame(maxWidth: .infinity, alignment: .trailing)
        }

        let layout2 = VStack(alignment: .leading, spacing: 2) {
            centerTop
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

        let layout3 = VStack(spacing: 0) {
            HStack(spacing: 8) {
                    centerTop
                    Spacer(minLength: 2)
                amountV
            }
            centerBottom
        }

        let layout4 = VStack(alignment: .leading, spacing: 2) {
            centerTop
            HStack(spacing: -4) {
                Spacer(minLength: 2)
#if DEBUG
                    .border(green)
#endif
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
            .accessibilityValue(needsKYC ? String(localized: ". Needs K Y C") :
                           shouldConfirm ? String(localized: ". Needs bank authorization") : EMPTYSTRING)
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
    static var previews: some View {
        List {
            TransactionRowView(transaction: withdrawal)
            TransactionRowView(transaction: payment)
        }
    }
}
// MARK: -
extension Transaction {             // for PreViews
    init(incoming: Bool, pending: Bool, id: String, time: Timestamp) {
        let effective = incoming ? 480 : 520
        let common = TransactionCommon(type: incoming ? .withdrawal : .payment,
                                    txState: TransactionState(major: pending ? TransactionMajorState.pending
                                                                             : TransactionMajorState.done),
                            amountEffective: Amount(currency: LONGCURRENCY, cent: UInt64(effective)),
                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 5),
                              transactionId: id,
                                  timestamp: time,
                                  txActions: [.abort])
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
                                               proposalId: "some proposal ID",
                                           totalRefundRaw: Amount(currency: LONGCURRENCY, cent: 300),
                                     totalRefundEffective: Amount(currency: LONGCURRENCY, cent: 280),
                                                  refunds: [],
                                        refundQueryActive: false)
            self = .payment(PaymentTransaction(common: common, details: pDetails))
        }
    }
}
#endif
