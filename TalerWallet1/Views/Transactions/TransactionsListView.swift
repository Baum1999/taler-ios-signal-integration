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

struct TransactionsListView: View {
    private let symLog = SymLogV()
    let navTitle = "Transactions"

    @ObservedObject var viewModel: TransactionsModel
    
    var body: some View {
        let reloadAction = viewModel.fetchTransactions
        VStack {
            if viewModel.transactions == nil {
                symLog { LoadingView(backButtonHidden: false) }
            } else {
                symLog { Content(symLog: symLog, viewModel: viewModel, reloadAction: reloadAction)
                        .navigationTitle(navTitle)
                }
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
extension TransactionsListView {
    struct Content: View {
        let symLog: SymLogV?
        @ObservedObject var viewModel: TransactionsModel

        var reloadAction: () async throws -> ()

        var body: some View {
            let transactions = viewModel.transactions!
            List(transactions) { transaction in
                let common = transaction.common()
                NavigationLink {
                    TransactionDetail(transaction: transaction)
                } label: {
                    TransactionRow(transaction: transaction)
                }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            symLog?.log("bookmarked \(common.transactionId)")
                            // TODO: Bookmark
                        } label: {
                            Label("Bookmark", systemImage: "bookmark")
                        }.tint(.indigo)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            symLog?.log("deleted \(common.transactionId)")
                            // TODO: delete from Model. SwiftUI deletes this row from view already :-)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
//struct TransactionsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TransactionsView()
//    }
//}
