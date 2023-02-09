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

struct ExchangeListView: View {
    private let symLog = SymLogV()
    let navTitle = "Exchanges"

    @ObservedObject var viewModel: ExchangeModel

    var body: some View {
        let reloadAction = viewModel.updateList
        VStack {
            if viewModel.exchanges == nil {
                symLog { LoadingView(backButtonHidden: false) }
            } else {
                Content(symLog: symLog, viewModel: viewModel, reloadAction: reloadAction)
                    .navigationTitle(navTitle)
            }
        }.task {
            symLog.log(".task")
            do {
                try await reloadAction()
            } catch {
                // TODO: show error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
// MARK: -
extension ExchangeListView {
    struct Content: View {
        let symLog: SymLogV
        @ObservedObject var viewModel: ExchangeModel
        var reloadAction: () async throws -> ()
        @State var showAlert: Bool = false
        @State var newExchange: String = "https://exchange-age.taler.ar/"

        func addExchange(_ exUrl: String) -> Void {
            Task {
                do {
                    symLog.log("adding: \(exUrl)")
                    try await viewModel.add(url: exUrl)
                    symLog.log("added: \(exUrl)")
                } catch {
                    symLog.log("error: \(error)")
                    // TODO: error handling - couldn't add exchangeURL
                }
            }
        }

        var body: some View {
            let plusAction: () -> Void = {
//                withAnimation { showPopup = true }
                showAlert = true
            }
            VStack {
                if viewModel.exchanges!.isEmpty {
                    Text("No Exchanges yet...")
                } else {
                    List(viewModel.exchanges!, id: \.self) { exchange in
                        VStack {
                            Text(exchange.exchangeBaseUrl)
                                .frame(maxWidth: .infinity)
                                .padding()
                            Text("Currency: " + (exchange.currency ?? "?"))
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                        .navigationBarTitleDisplayMode(.large)      // .inline
                        .refreshable {
                            do {
                                symLog.log("refreshing")
                                try await reloadAction()
                            } catch {
                                // TODO: error
                                symLog.log(error.localizedDescription)
                            }
                        }
                }
            }
                .navigationBarItems(trailing: PlusButton(action: plusAction))
                .textFieldAlert(isPresented: $showAlert, title: "Add Exchange",
                                doneText: "Add", text: $newExchange, action: addExchange)
        } // body
    }
}
