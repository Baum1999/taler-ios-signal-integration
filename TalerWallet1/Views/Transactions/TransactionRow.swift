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

struct TransactionRow: View {
    var transaction : Transaction

    var body: some View {
        let common = transaction.common()
        let details = transaction.detailsToShow()
        let keys = details.keys
        let amount = common.amountEffective
        let withdraw: Bool = common.type == WITHDRAWAL
        let payment: Bool = common.type == PAYMENT
        let refund: Bool = common.type == REFUND
        let incoming = withdraw || refund
//        let counterparty = transaction.exchangeBaseUrl
        let dateString = TalerDater.dateString(from: common.timestamp, relative: true)

        HStack {
            Image(systemName: incoming ? "text.badge.plus" : "text.badge.minus")
                .foregroundColor(incoming ? Color("Incoming")  : Color("Outgoing"))
                .padding(.trailing)
                .font(.largeTitle)

            if keys.contains(EXCHANGEBASEURL) {
                if let baseURL = details[EXCHANGEBASEURL] {
                    TransactionRowCenter(centerTop: baseURL.trimURL(), centerBottom: dateString)
                }
            } else if payment {
                TransactionRowCenter(centerTop: "Payment", centerBottom: dateString)
            } else if refund {
                TransactionRowCenter(centerTop: "Refund", centerBottom: dateString)
            }
            Spacer()
            VStack(alignment: .trailing) {
                let sign = incoming ? "+" : "-"
                Text(sign + "\(amount.valueStr)")
                    .font(.title)
                    .foregroundColor(incoming ? Color("Incoming")  : Color("Outgoing"))
            }
        }
        .padding(.top)
    }
}

#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var withdrawal = Transaction(incoming: true,
                                              id: "some withdrawal ID",
                                            time: Timestamp(from: 1_666_000_000_000))
    static var payment = Transaction(incoming: false,
                                        id: "some payment ID",
                                        time: Timestamp(from: 1_666_666_000_000))
    static var previews: some View {
        VStack {
            TransactionRow(transaction: withdrawal)
            TransactionRow(transaction: payment)
        }
    }
}
#endif
