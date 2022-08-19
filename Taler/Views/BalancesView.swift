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

struct BalancesView: View {
    @ObservedObject var balancesModel: BalancesModel
    @EnvironmentObject var backend: BackendManager
    var showSidebar: () -> Void
    
    var body: some View {
        NavigationView {
            switch balancesModel.state {
            case .begin:
                EmptyView()
                    .onAppear(perform: {
                        balancesModel.getBalances()
                    })
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )
            case .loading:
                ProgressView()
                    .navigationTitle("Balances")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        })
                    )
            case .loaded(let balances):
                VStack {
                    Text("Balances")
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
    
    /*init(showSidebar: @escaping () -> Void) {
        self.showSidebar = showSidebar
    }*/
}
