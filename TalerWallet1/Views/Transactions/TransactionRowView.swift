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
struct TransactionRowContentV: View {
    var centerTop: String
    var centerBottom: String
    let isHorizontal: Bool
    let pending: Bool
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool
    let done: Bool
    let foreColor:Color

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public static func width(titles: (String, String?), isHorizontal: Bool,
                             sizeCategory: ContentSizeCategory) -> CGFloat {
        let imageFont = TalerFont.uiFont(.largeTitle)
        let uiFont1 = TalerFont.uiFont(.headline)
        let uiFont2 = TalerFont.uiFont(.callout)

        let image = "++"
        let imageWidth = image.widthOfString(usingUIFont: imageFont, sizeCategory) + 8.0     // spacing: 8
        let (title1, title2) = titles
        let title1Width = title1.widthOfString(usingUIFont: uiFont1, sizeCategory)
        var title2Width = 0.0
        var totalWidth = title1Width
        if let title2 {
            title2Width = title2.widthOfString(usingUIFont: uiFont2, sizeCategory)
            let blankStr = " "
            totalWidth += blankStr.widthOfString(usingUIFont: uiFont1, sizeCategory) + title2Width
        }

//    let logStr = String(format: "image: %.2f   title: %.2f   total: %.2f", imageWidth, max(title1Width, title2Width), totalWidth)
//    print(logStr)
        return imageWidth + (isHorizontal ? totalWidth
                                          : max(title1Width, title2Width))
    }

    var body: some View {
        let iconBadge = IconBadge(foreColor: foreColor, done: done, incoming: incoming,
                              shouldConfirm: shouldConfirm, needsKYC: needsKYC)
        let doneOrPending = done || pending
        let increasedContrast = colorSchemeContrast == .increased
        let textColor = doneOrPending ? .primary :
                    increasedContrast ? .secondary : WalletColors().gray3
        HStack(spacing: 8) {
            iconBadge
            VStack(alignment: .leading) {
                Text(centerTop)
                    .foregroundColor(textColor)
                    .strikethrough(!doneOrPending, color: .red)
                    .accessibilityFont(.headline)
//                  .fontWeight(.medium)      iOS 16
                    .padding(.bottom, -2.0)
                    .accessibilityLabel(doneOrPending ? centerTop : centerTop +  ", canceled")
                Text(centerBottom)
                    .foregroundColor(textColor)
                    .accessibilityFont(.callout)
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction : Transaction
    let currency: String

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (contentWidth + valueWidth + 40)
    }

    var body: some View {
        let common = transaction.common
        let amount = common.amountEffective
        let pending = transaction.isPending
        let needsKYC = transaction.isPendingKYC
        let shouldConfirm = transaction.shouldConfirm
        let done = transaction.isDone
        let details = transaction.detailsToShow()
        let keys = details.keys

        let (dateString, date) = TalerDater.dateString(from: common.timestamp, relative: true)
        let incoming = common.incoming()
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                      : done ? WalletColors().transactionColor(incoming)
                             : WalletColors().incompleteColor
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        SingleAxisGeometryReader { width in
            Group {
                let amountStr = amount.string(currencyInfo)
                let amountWidth = amountStr.width(largeAmountFont: false, sizeCategory)

                let contentWidth = TransactionRowContentV.width(titles: (transaction.localizedType, dateString),
                                                          isHorizontal: false, sizeCategory: sizeCategory)
                let needVStack = needVStack(available: width, contentWidth: contentWidth, valueWidth: amountWidth)

                AmountRowV(amountStr: amountStr, amountColor: foreColor, doneOrPending: done || pending,
                     largeAmountFont: false, fitsHorizontal: !needVStack, vertAlignment: .center) {

                    TransactionRowContentV(centerTop: transaction.localizedType,
                                        centerBottom: dateString, isHorizontal: true,
                                             pending: pending, incoming: incoming,
                                       shouldConfirm: shouldConfirm, needsKYC: needsKYC,
                                                done: done, foreColor: foreColor)
                }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(needsKYC ? ". Needs K Y C" :
                                   shouldConfirm ? ". Needs bank confirmation" : EMPTYSTRING)
                    .accessibilityHint("Will go to detail view.")
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
