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

struct PendingOpView: View {
    var pendingOp: PendingOperation
    @State var polling: Bool = false
    @State var liveliness: Bool = false
    @State var isDue: Bool = false

    var body: some View {
        Section {
            Text(pendingOp.exchangeBaseUrl)
            Text(pendingOp.id)
                .font(.caption)
            Toggle("isLongPolling", isOn: $polling)
                .disabled(true)
            Toggle("givesLifeness", isOn: $liveliness)
                .disabled(true)
            Toggle("isDue", isOn: $isDue)
                .disabled(true)
            let dateString = TalerDater.dateString(from: pendingOp.timestampDue)
            Text("\(dateString)")
        } header: {
            Text(pendingOp.type)
                .font(.title2)
        }
//        .textCase(nil)    // don't capitalize
        .onAppear {
            polling = pendingOp.isLongpolling
            liveliness = pendingOp.givesLifeness
            isDue = pendingOp.isDue
        }
    }
}

struct PendingOpView_Previews: PreviewProvider {
    static var pending1 = PendingOperation(type: "exchange-check-refresh",
                                exchangeBaseUrl: "https://exchange.demo.taler.net/",
                                             id: "exchange-update:https://exchange.demo.taler.net/",
                                  isLongpolling: false,
                                  givesLifeness: true,
                                          isDue: false,
                                   timestampDue: Timestamp(from:1669931055000))
    static var previews: some View {
        Form {
            PendingOpView(pendingOp: pending1)
        }
    }
}
