/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct IconBadge: View {
    let foreColor:Color
    let done: Bool
//    let pending: Bool
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    var body: some View {
        let imageName = incoming && done ? DONE_INCOMING
                              : incoming ? PENDING_INCOMING
                // since the money already left the wallet, show DONE
                                         : DONE_OUTGOING        // PENDING_OUTGOING
        let badgeName = needsKYC ? NEEDS_KYC
                                 : CONFIRM_BANK
        HStack(alignment: .top, spacing: -8) {      // TODO: adapt spacing to dynamic fontsize
            ZStack {
                // "plus.diamond" is wider than "plus.circle.fill"
                // ZStack centers the main icon, and the badge will always be at the same position
                Image(systemName: PENDING_INCOMING)
                    .foregroundColor(.clear)
                Image(systemName: imageName)
                    .foregroundColor(foreColor)
            }.accessibilityFont(.largeTitle)
            Image(systemName: badgeName)
                .accessibilityFont(.caption)
                .foregroundColor((needsKYC || shouldConfirm) ? .red : .clear)
        }.accessibilityHidden(true)
    }
}

struct TransactionRowView: View {
    let transaction : Transaction
    let currency: String

    @Environment(\.sizeCategory) var sizeCategory
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

        let (dateString, date) = TalerDater.dateString(from: common.timestamp, relative: true)
        let incoming = common.incoming()
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                      : done ? WalletColors().transactionColor(incoming)
                             : WalletColors().uncompletedColor
        let textColor = doneOrPending ? .primary :
                    increasedContrast ? .secondary : Color(.tertiaryLabel)

        let iconBadge = IconBadge(foreColor: foreColor, done: done, incoming: incoming,
                                  shouldConfirm: shouldConfirm, needsKYC: needsKYC)
        let amountV = AmountV(common.amountEffective)
            .foregroundColor(foreColor)

        let topString = topString()
        let centerTop = Text(topString)
            .foregroundColor(textColor)
            .strikethrough(!doneOrPending, color: .red)
            .accessibilityFont(.headline)
//            .fontWeight(.medium)      iOS 16
            .padding(.bottom, -2.0)
            .accessibilityLabel(doneOrPending ? topString : topString +  ", canceled")
        let centerBottom = Text(dateString)
            .foregroundColor(textColor)
            .accessibilityFont(.callout)

        let layout1 = HStack(spacing: 0) {
            HStack(spacing: -4) {
                iconBadge
                Spacer(minLength: 0)
                VStack(alignment: .leading) {
                    centerTop
                    centerBottom
                }
                Spacer(minLength: 2)
            }
            amountV
        }

        let layout2 = VStack(spacing: 0) {
            centerTop
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    iconBadge//.border(.blue)
                    Spacer(minLength: 0)
                    centerBottom
                    Spacer(minLength: 2)
                }//.border(.green)
                amountV//.border(.red)
            }//.border(.orange)
        }

        let layout3 = VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    iconBadge
                    Spacer(minLength: 0)
                    centerTop
                    Spacer(minLength: 2)
                }
                amountV
            }
            centerBottom
        }

        let layout4 = VStack(spacing: 0) {
            centerTop
            HStack(spacing: -4) {
                iconBadge//.border(.green)
                Spacer(minLength: 2
                )
                amountV//.border(.green)
            }//.border(.orange)
            centerBottom
        }

        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    layout1//.border(.green)
                    layout2
                    layout3//.border(.red)
                    layout4//.border(.blue)
                }
            } else { layout4 } // view for iOS 15
        }
            .accessibilityElement(children: .combine)
            .accessibilityValue(needsKYC ? ". Needs K Y C" :
                           shouldConfirm ? ". Needs bank confirmation" : EMPTYSTRING)
            .accessibilityHint("Will go to detail view.")
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
            TransactionRowView(transaction: withdrawal, currency: TESTCURRENCY)
            TransactionRowView(transaction: payment, currency: DEMOCURRENCY)
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
                                     totalRefundEffective: Amount(currency: LONGCURRENCY, cent: 280))
            self = .payment(PaymentTransaction(common: common, details: pDetails))
        }
    }
}
#endif
