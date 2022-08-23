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

struct TransactionsView: View {
    @ObservedObject var model: TransactionsModel
    
    var body: some View {
        VStack {
            if model.transactions == nil {
                ProgressView()
                    .onAppear {
                        model.loadTransactions()
                    }
            } else if model.loading {
                ProgressView()
            } else {
                List(model.transactions!, id: \.self) { tx in
                    VStack {
                        Text("Transaction: \(tx.transactionId)")
                    }
                }
                Text("Loaded")
                /*VStack {
                    Text("Balances")
                    NavigationLink {
                        TransactionsView(model: self.balancesModel.getTransactionsModel())
                    } label: {
                        Text("Transactions")
                    }

                }
                    .padding(16)
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )*/
            }
        }
            .navigationTitle("Transactions")
    }
}

struct BalancesView: View {
    @ObservedObject var balancesModel: BalancesModel
    @EnvironmentObject var backend: BackendManager
    var showSidebar: () -> Void
    
    var body: some View {
        NavigationView {
            if balancesModel.balances == nil {
                ProgressView()
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )
                    .onAppear {
                        balancesModel.getBalances()
                    }
            } else if balancesModel.loading {
                ProgressView()
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )
            } else {
                VStack {
                    Text("Balances")
                    NavigationLink {
                        TransactionsView(model: self.balancesModel.getTransactionsModel())
                    } label: {
                        Text("Transactions")
                    }

                }
                    .padding(16)
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )
            }
        }
    }
}
