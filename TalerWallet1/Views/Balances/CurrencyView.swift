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

/// This view shows a currency
/// Header: Currency Name (e.g. Kudos)
/// [Send Funds]  [Receive Funds]     Balance
/// Pending Incoming
/// Pending Outgoing

struct CurrencyView: View {
    var balance:Balance
    let sendAction: () -> Void
    let recvAction: () -> Void
    var body: some View {
        VStack {
            Text(balance.available.currencyStr)
                .font(.title)
            BalanceRow(amount: balance.available, sendAction: sendAction, recvAction: recvAction)

            let inAmount = balance.pendingIncoming
            if !inAmount.isZero {
                PendingRow(amount: inAmount, incoming: true, counterparty: "exchange.demo.taler.net")
            }
            let outAmount = balance.pendingOutgoing
            if !outAmount.isZero {
                PendingRow(amount: outAmount, incoming: false, counterparty: "merchant")
            }
        }
//            .padding()
    }
}

struct CurrencyView_Previews: PreviewProvider {
    static var balance = Balance(available: try! Amount(fromString: "Taler:0.1"),
                                 pendingIncoming: try! Amount(fromString: "Taler:4.8"),
                                 pendingOutgoing: try! Amount(fromString: "Taler:3.25"),
                                 hasPendingTransactions: true,
                                 requiresUserInput: false)
    
    static var previews: some View {
        CurrencyView(balance: balance, sendAction: {}, recvAction: {})
    }
}
