/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import SwiftUI
import taler_swift

struct TransactionDetail: View {
    var transaction : Transaction

    var body: some View {
        let common = transaction.common()
        let dateString = TalerDater.dateString(from: common.timestamp)

        VStack() {
            Spacer()
            Text("\(common.type)")      // TODO: translation
                .font(.title)
                .fontWeight(.medium)
                .padding(.bottom)
            Spacer()
            Text("\(dateString)")
                .font(.title2)
                .padding(.vertical)
            switch transaction {
                case .withdrawal(let withdrawalTransaction):
                    details(transaction: transaction)
                    threeAmounts(common: common, topTitle: "Chosen amount to withdraw:", bottomTitle: "Obtained coins:", incoming: true)
                case .payment(let paymentTransaction):
                    let details = paymentTransaction.details
                    let info = details.info
                    Text("Status: \(details.status)")
                        .font(.title2)
                        .padding(.bottom)
                    Text(info.summary)
                        .font(.title)
                        .lineLimit(4)
                        .padding(.bottom)
                    threeAmounts(common: common, topTitle: "Sum to be paid:", bottomTitle: "Paid coins:", incoming: false)
                case .refund(let refundTransaction):
                    threeAmounts(common: common, topTitle: "Refunded amount:", bottomTitle: "Obtained coins:", incoming: true)
                case .tip(let tipTransaction):
                    threeAmounts(common: common, topTitle: "Tip to be paid:", bottomTitle: "Paid coins:", incoming: false)
                case .refresh(let refreshTransaction):
                    threeAmounts(common: common, topTitle: "Refreshed amount:", bottomTitle: "Paid coins:", incoming: false)
            }
            Spacer()
            Button(role: .destructive, action: {
                // TODO: delete from wallet-core
                print("Should delete \(common.transactionId)")
            }, label: {
                HStack {
                    Text("Delete from list" + "        ")
                    Image(systemName: "trash")
                }
                    .font(.title)
                    .frame(maxWidth: .infinity)
            })
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}

extension TransactionDetail {
    struct threeAmounts: View {
        var common: TransactionCommon
        var topTitle: String
        var bottomTitle: String
        var incoming: Bool

        var body: some View {
            let raw = common.amountRaw
            let effective = common.amountEffective
            let fee = common.fee()
            let labelColor = Color(UIColor.label)
            let outColor = Color("Outgoing")
            let inColor = Color("Incoming")

            AmountView(title: topTitle,
                       value: raw.readableDescription,
                       color: labelColor)
                .padding(.bottom)
            AmountView(title: "Exchange fee:",
                       value: fee.readableDescription,
                       color: fee.isZero ? labelColor : outColor)
                .padding(.bottom)
            AmountView(title: bottomTitle,
                       value: effective.readableDescription,
                       color: incoming ? inColor : outColor)
                .padding(.bottom)
        }
    }
    struct details: View {
        var transaction : Transaction
        var body: some View {
            let details = transaction.detailsToShow()
            let keys = details.keys
            if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    Text("from \(baseURL.trimURL())")
                        .font(.title2)
                        .padding(.bottom)
                }
            }
        }
    }
}

#if DEBUG
struct TransactionDetail_Previews: PreviewProvider {
    static var withdrawal = Transaction(incoming: true,
                                        id: "some withdrawal ID",
                                        time: Timestamp(from: 1_666_000_000_000))
    static var payment = Transaction(incoming: false,
                                     id: "some payment ID",
                                     time: Timestamp(from: 1_666_666_000_000))
    static var previews: some View {
        Group {
            TransactionDetail(transaction: withdrawal)
            TransactionDetail(transaction: payment)
        }
    }
}
#endif
