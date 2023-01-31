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

struct PendingRow: View {
    let amount: Amount
    let incoming: Bool
    let counterparty: String
    var body: some View {
        HStack {
            Image(systemName: incoming ? "text.badge.plus" : "text.badge.minus")
                .padding(.trailing)
                .font(.largeTitle)
                .foregroundColor(incoming ? Color("PendingIncoming")  : Color("PendingOutgoing"))

            VStack(alignment: .leading) {
                Text("\(counterparty)")
                    .font(.headline)
                    .fontWeight(.medium)
                Text("Waiting for confirmation")
                    .font(.callout)
                    .padding(.vertical, -2.0)
                Text("some time ago")       // TODO: show time-interval
                    .font(.callout)
            }
            Spacer()
            VStack(alignment: .trailing) {
                let sign = incoming ? "+" : "-"
                Text(sign + "\(amount.valueStr)")
                    .font(.title)
                    .foregroundColor(Color.gray)
                Text("PENDING")
                    .font(.callout)
            }
        }
        .padding(.top)
    }
}

struct PendingRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PendingRow(amount: try! Amount(fromString: "Taler:4.8"), incoming: true, counterparty: "exchange.demo.taler.net")
            PendingRow(amount: try! Amount(fromString: "Taler:3.25"), incoming: false, counterparty: "merchant")
        }
    }
}
