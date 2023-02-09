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
        let raw = transaction.amountRaw
        let effective = transaction.amountEffective
        let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
        let dateString = TalerDater.dateString(from: transaction.timestamp)

        VStack() {
            Spacer()
            Text("\(dateString)")
                .font(.title)
                .fontWeight(.medium)
                .padding(.bottom)
            AmountView(title: "Chosen amount to withdraw:",
                       value:  raw.readableDescription, color: Color(UIColor.label))
                .padding(.bottom)
            AmountView(title: "Exchange fee:",
                       value: fee.readableDescription, color: Color("Outgoing"))
                .padding(.bottom)
            AmountView(title: "Obtained coins:",
                       value: effective.readableDescription, color: Color("Incoming"))
                .padding(.bottom)
            if let baseURL = transaction.exchangeBaseUrl {
                VStack {
                    Text("From exchange:")
                        .font(.title3)
                    Text("\(baseURL.trimURL())")
                        .font(.title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer()
            Button(role: .destructive, action: {
                // TODO: delete from wallet-core
                print("Should delete \(transaction.transactionId)")
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
//            Spacer()
        }
    }
}

#if DEBUG
struct TransactionDetail_Previews: PreviewProvider {
    static var transaction = Transaction(id:"some transActionID", time: Timestamp(from: 1_666_000_000_000))
    static var previews: some View {
        TransactionDetail(transaction: transaction)
    }
}
#endif
