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

struct PendingOpsListView: View {
    private let symLog = SymLogV()
    let navTitle = "Pending"

    @ObservedObject var viewModel: PendingModel
    var hamburgerAction: () -> Void

    var body: some View {
        let reloadAction = viewModel.update
        VStack {
            if viewModel.pendingOperations == nil {
                symLog { LoadingView(backButtonHidden: true) }
            } else {
                symLog { NavigationView {
                    Content(symLog: symLog, viewModel: viewModel, reloadAction: reloadAction)
                        .navigationBarItems(leading: HamburgerButton(action: hamburgerAction))
                } }
                .navigationTitle(navTitle)
            }
        }.task {
            symLog.log(".task")
            try? await reloadAction()       // TODO: catch error
        }
    }
}
// MARK: -
extension PendingOpsListView {
    struct Content: View {
        let symLog: SymLogV?
        @ObservedObject var viewModel: PendingModel
//        @EnvironmentObject var controller : Controller
        var reloadAction: () async throws -> ()

        var body: some View {
            Group {
                List(viewModel.pendingOperations!, id: \.self) { pendingOp in
                    PendingOpView(pendingOp: pendingOp)
                }
                .navigationBarTitleDisplayMode(.large)      // .inline
                .refreshable {
                    symLog?.log("refreshing")
                    try? await reloadAction()       // TODO: catch error
                }
            }
        }
    }
}
