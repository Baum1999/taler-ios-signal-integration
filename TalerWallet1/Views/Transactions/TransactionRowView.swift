/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TransactionRowCenter: View {
    var centerTop: String
    var centerBottom: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(centerTop)")
                .font(.headline)
                .fontWeight(.medium)
                .padding(.bottom, -2.0)
            Text("\(centerBottom)")
                .font(.callout)
        }
    }
}

struct TransactionRowView: View {
    var transaction : Transaction

    var body: some View {
        let common = transaction.common
        let amount = common.amountEffective
        let pending = transaction.isPending
        let done = transaction.isDone
        let details = transaction.detailsToShow()
        let keys = details.keys

        let dateString = TalerDater.dateString(from: common.timestamp, relative: true)
        let incoming = common.incoming()
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                      : done ? WalletColors().transactionColor(incoming)
                             : WalletColors().uncompletedColor

        HStack(spacing: 6) {
            Image(systemName: incoming ? "text.badge.plus" : "text.badge.minus")
                .foregroundColor(foreColor)
                .font(.largeTitle)
                .accessibility(hidden: true)

            TransactionRowCenter(centerTop: transaction.localizedType,
                                 centerBottom: dateString)
            Spacer()
            VStack(alignment: .trailing) {
                let sign = incoming ? "+" : "-"
                Text(sign + "\(amount.valueStr)")
                    .font(.title)
                    .foregroundColor(foreColor)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.top)
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
        let currency = LONGCURRENCY
        let raw = currency + ":5"
        let effective = currency + (incoming ? ":4.8"
                                             : ":5.2")
        let refRaw = currency + ":3"
        let refEff = currency + ":2.8"
        let common = TransactionCommon(type: incoming ? .withdrawal : .payment,
                                    txState: TransactionState(major: pending ? TransactionMajorState.pending
                                                                             : TransactionMajorState.done),
                            amountEffective: try! Amount(fromString: effective),
                                  amountRaw: try! Amount(fromString: raw),
                              transactionId: id,
                                  timestamp: time,
                                  txActions: [.abort])
        let now = Timestamp.now()
        if incoming {
            // if pending then manual else bank-integrated
            let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company&amount=KUDOS%3A9.99&message=Taler+Withdrawal+J41FQPJGAP1BED1SFSXHC989EN8HRDYAHK688MQ228H6SKBMV0AG"
            let withdrawalDetails = WithdrawalDetails(type: pending ? WithdrawalDetails.WithdrawalType.manual
                                                                    : WithdrawalDetails.WithdrawalType.bankIntegrated,
                                                reservePub: "PuBlIc_KeY_oF_tHe_ReSeRvE",
                                            reserveIsReady: false,
                                         exchangePaytoUris: pending ? [payto] : nil)
            let wDetails = WithdrawalTransactionDetails(exchangeBaseUrl: DEMOEXCHANGE,
                                                      withdrawalDetails: withdrawalDetails)
            self = .withdrawal(WithdrawalTransaction(common: common, details: wDetails, loaded: now))
        } else {
            let merchant = Merchant(name: "some random shop")
            let info = OrderShortInfo(orderId: "some order ID",
                                     merchant: merchant,
                                      summary: "some product summary",
                                     products: [])
            let pDetails = PaymentTransactionDetails(proposalId: "some proposal ID",
                                                 totalRefundRaw: try! Amount(fromString: refRaw),
                                           totalRefundEffective: try! Amount(fromString: refEff),
                                                           info: info)
            self = .payment(PaymentTransaction(common: common, details: pDetails, loaded: now))
        }
    }
}
#endif
