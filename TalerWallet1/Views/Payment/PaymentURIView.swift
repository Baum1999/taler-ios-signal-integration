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

struct PaymentURIView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var viewModel: PaymentURIModel

//    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    let navTitle = "Payment"
    var cancelButton: some View {
        Button("Cancel5") { dismissTop() }
    }

    @State var detailsForUri: PaymentDetailsForUri?

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if viewModel.paymentState == nil {
                LoadingView(backButtonHidden: false)
            } else { switch viewModel.paymentState {
                case .waitingForUriDetails:
                    let _ = symLog.vlog("waitingForUriDetails")
                    WithdrawProgressView(message: url.host ?? badURL) { dismissTop() }
                        .navigationTitle("Contacting Exchange")
                case .receivedUriDetails:
                    let _ = symLog.vlog("waitingForUser")
                    PaymentAcceptView(viewModel: viewModel, detailsForAmount: detailsForUri!)
                default:
                    symLog {
                        Text("Payment")
                            .navigationBarItems(leading: cancelButton)
                            .navigationTitle(navTitle)
                    }
            } }
        }.task {
            do { // TODO: cancelled
                symLog.log(".task")
                detailsForUri = try await viewModel.preparePayForUri(url.absoluteString)
//                print(detailsForUri?.status)
//                print(detailsForUri?.amountRaw.description)
//                print(detailsForUri?.amountEffective.description)
//                print(detailsForUri?.proposalId)
            } catch {
                symLog.log(error.localizedDescription)                // TODO: error
            }
        }
    }
}
