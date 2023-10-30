/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TransactionRowContentV: View {
    var centerTop: String
    var centerBottom: String
    let isHorizontal: Bool
    let incoming: Bool
    let foreColor:Color

    public static func width(titles: (String, String?), isHorizontal: Bool) -> CGFloat {
        let imageFont = TalerFont.uiFont(.largeTitle)
        let uiFont1 = TalerFont.uiFont(.headline)
        let uiFont2 = TalerFont.uiFont(.callout)

        let image = "++"
        let imageWidth = image.widthOfString(usingUIFont: imageFont) + 8.0     // spacing: 8
        let (title1, title2) = titles
        let title1Width = title1.widthOfString(usingUIFont: uiFont1)
        var title2Width = 0.0
        var totalWidth = title1Width
        if let title2 {
            title2Width = title2.widthOfString(usingUIFont: uiFont2)
            let blankStr = " "
            totalWidth += blankStr.widthOfString(usingUIFont: uiFont1) + title2Width
        }

//    let logStr = String(format: "image: %.2f   title: %.2f   total: %.2f", imageWidth, max(title1Width, title2Width), totalWidth)
//    print(logStr)
        return imageWidth + (isHorizontal ? totalWidth
                                          : max(title1Width, title2Width))
    }

    var body: some View {
        let imageName = incoming ? "plus.circle.fill"
                                 : "minus.circle.fill"
        HStack(spacing: 8) {
            Image(systemName: imageName)
                .foregroundColor(foreColor)
                .accessibilityFont(.largeTitle)
                .accessibility(hidden: true)

            VStack(alignment: .leading) {
                Text(centerTop)
                    .accessibilityFont(.headline)
//                  .fontWeight(.medium)      iOS 16
                    .padding(.bottom, -2.0)
                Text(centerBottom)
                    .accessibilityFont(.callout)
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction : Transaction
    let currencyInfo: CurrencyInfo?

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (contentWidth + valueWidth + 40)
    }

    var body: some View {
        let common = transaction.common
        let amount = common.amountEffective
        let pending = transaction.isPending
        let done = transaction.isDone
        let details = transaction.detailsToShow()
        let keys = details.keys

        let (dateString, date) = TalerDater.dateString(from: common.timestamp, relative: true)
        let incoming = common.incoming()
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                      : done ? WalletColors().transactionColor(incoming)
                             : WalletColors().uncompletedColor

        SingleAxisGeometryReader { width in
            Group {
                let amountStr = amount.string(currencyInfo)
                let amountWidth = amountStr.width(largeAmountFont: false)

                let contentWidth = TransactionRowContentV.width(titles: (transaction.localizedType, dateString),
                                                            isHorizontal: false)
                let needVStack = needVStack(available: width, contentWidth: contentWidth, valueWidth: amountWidth)

                AmountRowV(amountStr: amountStr, amountColor: foreColor, largeAmountFont: false,
                           fitsHorizontal: !needVStack, vertAlignment: .center) {

                    TransactionRowContentV(centerTop: transaction.localizedType,
                                           centerBottom: dateString, isHorizontal: true, incoming: incoming, foreColor: foreColor)
                }
            }
        }
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
        let testInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 0)
        let demoInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 2)
        let test = try! Amount(fromString: TESTCURRENCY + ":1.23")
        let demo = try! Amount(fromString: DEMOCURRENCY + ":1234.56")
        List {
            TransactionRowView(transaction: withdrawal, currencyInfo: testInfo)
            TransactionRowView(transaction: payment, currencyInfo: demoInfo)
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
            self = .withdrawal(WithdrawalTransaction(common: common, details: wDetails))
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
            self = .payment(PaymentTransaction(common: common, details: pDetails))
        }
    }
}
#endif
