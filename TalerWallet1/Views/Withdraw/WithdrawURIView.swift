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

struct WithdrawURIView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var viewModel: WithdrawURIModel

//    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    let navTitle = "Withdraw"
    var cancelButton: some View {
        Button("Cancel1") { dismissTop() }
    }

    @State var detailsForUri: WithdrawalDetailsForUri?
    @State var detailsForAmount: WithdrawalDetailsForAmount?
    @State var didAcceptTOS: Bool = false

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if viewModel.withdrawState == nil {
                LoadingView(backButtonHidden: false)
            } else { switch viewModel.withdrawState {
                case .waitingForUriDetails:
                    let _ = symLog.vlog("waitingForUriDetails")
                    WithdrawProgressView(message: url.host ?? badURL) { dismissTop() }
                        .navigationTitle("Contacting Exchange")
                case .waitingForAmountDetails:
                    let _ = symLog.vlog("waitingForAmountDetails")
                    WithdrawProgressView(message: detailsForUri!.defaultExchangeBaseUrl ?? badURL) { dismissTop() }
                        .navigationTitle("Found Exchange")
                case .receivedAmountDetails, .waitingForTOS, .receivedTOS, .receivedTOSAck:
                    let _ = symLog.vlog("waitingForTOS")
                    if !didAcceptTOS {
                        WithdrawTOSView(url: url, model: viewModel, detailsForUri: detailsForUri!, didAcceptTOS: $didAcceptTOS)
                    } else {
                        // show Amount details and let user accept
                        WithdrawAcceptView(url: url, model: viewModel, detailsForAmount: detailsForAmount!,
                                           baseURL:  detailsForUri!.defaultExchangeBaseUrl!)
                    }
                default:
                    symLog {
                        Content(symLog: symLog, viewModel: viewModel)
                            .navigationBarItems(leading: cancelButton)
                            .navigationTitle(navTitle)
                    }
            } }
        }.task {
            do { // TODO: cancelled
                symLog.log(".task")
                detailsForUri = try await viewModel.loadWithdrawalDetailsForURI(url.absoluteString)
                let baseURL = detailsForUri!.defaultExchangeBaseUrl
                symLog.log("amount: \(detailsForUri!.amount), baseURL: \(String(describing: baseURL))")
                // TODO: let user choose exchange from array
                detailsForAmount = try await viewModel.loadWithdrawalDetailsForAmount(detailsForUri!)
                symLog.log("raw: \(detailsForAmount!.amountRaw), effective: \(detailsForAmount!.amountEffective)")
                if detailsForAmount!.tosAccepted {
                    didAcceptTOS = true
                }
            } catch {
                // TODO: error
            }
        }
    }
}
// MARK: -
extension WithdrawURIView {
    struct Content: View {
        let symLog: SymLogV?
        @ObservedObject var viewModel: WithdrawURIModel
//        @EnvironmentObject var controller : Controller

        var body: some View {
            Group {
                Text("Hello")
//                List(model.pendingOperations!, id: \.self) { pendingOp in
//                    PendingOpView(pendingOp: pendingOp)
//                }
//                .navigationBarTitleDisplayMode(.large)      // .inline
//                .refreshable {
//                    symLog?.log("refreshing")
//                    try? await reloadAction()       // TODO: catch error
//                }
            }
        }
    }
}
