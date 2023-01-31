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
import SymLog

struct URLSheet: View {
    private let symLog = SymLogV()
    var urlToOpen: URL
    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    @EnvironmentObject private var controller: Controller

    @State private var urlCommand: UrlCommand? = nil

    var cancelButton: some View {
        Button("Cancel0") {
            print(dismiss)
            dismissTop()
        }
    }

    var body: some View {
        symLog {
            NavigationView {
                if urlCommand == UrlCommand.withdraw {
                    WithdrawURIView(url: urlToOpen, viewModel: controller.withdrawURIModel)
                } else if urlCommand == UrlCommand.pay {
                    PaymentURIView(url: urlToOpen, viewModel: controller.paymentURIModel)
                } else {
                    VStack {        // show Error view with cancelButton
                        Spacer()
                        Text(controller.messageForSheet ?? urlToOpen.absoluteString)
                            .font(.title)
                        Spacer()
                        Spacer()
                    }
                        .navigationBarItems(leading: cancelButton)
                        .navigationTitle("Invalid URL")
                }
            }.task {
                urlCommand = controller.openURL(urlToOpen)
            }
        }
    }
}
// MARK: -
//struct PaySheet_Previews: PreviewProvider {
//    static var previews: some View {
            // needs BackendManager
//        URLSheet(urlToOpen: URL(string: "ftp://this.URL.is.invalid")!)
//    }
//}
