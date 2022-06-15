/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
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

struct BalanceRow: View {
    var balance: Balance
    
    var body: some View {
        VStack(alignment: .leading, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
            Text("Available: \(balance.available.description)")
            Text("Pending Incoming: \(balance.pendingIncoming.description)")
            Text("Pending Outgoing: \(balance.pendingOutgoing.description)")
            Text("Requires User Input: \(balance.requiresUserInput.description)")
        })
        .padding()
    }
}

struct BalanceRow_Previews: PreviewProvider {
    static var previews: some View {
        try! BalanceRow(balance: Balance(available: Amount(fromString: "USD:0.01"), pendingIncoming: Amount(fromString: "USD:0.02"), pendingOutgoing: Amount(fromString: "USD:0.03"), requiresUserInput: true))
    }
}
