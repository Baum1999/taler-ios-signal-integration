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

struct WithdrawProgressView: View {
    let message: String
    let action: () -> Void

    var cancelButton: some View {
        Button("Cancel2") {
            action()
        }           // dismiss the sheet
    }

    var body: some View {                       // show Message with cancelButton
        VStack {
            Spacer()
            ProgressView()
            Spacer()
            Text(message)
                .font(.title)
            Spacer()
            Spacer()
        }.navigationBarItems(leading: cancelButton)
    }
}

struct WithdrawProgressView_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawProgressView(message: "message") {}
    }
}
