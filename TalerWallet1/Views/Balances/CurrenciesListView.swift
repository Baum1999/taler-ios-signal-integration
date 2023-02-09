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

struct CurrenciesListView: View {
    private let symLog = SymLogV()
    let navTitle = "GNU Taler Wallet"

    @ObservedObject var viewModel: BalancesModel
    var hamburgerAction: () -> Void

    var body: some View {
        let reloadAction = viewModel.fetchBalances
        VStack {
            if viewModel.balances == nil {
                symLog { LoadingView(backButtonHidden: true) }
            } else {
                symLog { NavigationView {
                    Content(symLog: symLog, viewModel: viewModel, reloadAction: reloadAction)
                        .navigationBarItems(leading: HamburgerButton(action: hamburgerAction))
                        .navigationTitle(navTitle)
                } }
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
extension CurrenciesListView {
    struct Content: View {
        let symLog: SymLogV?
        @ObservedObject var viewModel: BalancesModel
        @EnvironmentObject var controller : Controller
        var reloadAction: () async throws -> ()

        var body: some View {
            if viewModel.balances!.isEmpty {        // TODO: all spent?
                WalletEmptyView()
                    .navigationBarTitleDisplayMode(.large)
            } else {
                List (viewModel.balances!, id: \.self) { balance in
                    NavigationLink {
                        TransactionsListView(viewModel: controller.transactionsModel)
                    } label: {
                        // TODO: sendAction, recvAction
                        CurrencyView(balance: balance, sendAction: {}, recvAction: {})
                    }
                }
                    .navigationBarTitleDisplayMode(.large)      // .inline
                    .refreshable {
                        do {
                            symLog?.log("refreshing")
                            try await reloadAction()
                        } catch {
                            // TODO: error
                            symLog?.log(error.localizedDescription)
                        }
                    }
            }
        }
    }
}
