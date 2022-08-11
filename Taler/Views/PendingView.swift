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

struct PendingView: View {
    @ObservedObject var pendingManager: PendingManager
    
    var showSidebar: () -> Void
    var body: some View {
        NavigationView {
            if pendingManager.items == nil {
                ProgressView()
                    .navigationTitle("Pending")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        }))
                    .onAppear {
                        pendingManager.update()
                    }
            } else if pendingManager.loading {
                ProgressView()
                    .navigationTitle("Pending")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        }))
            } else {
                let items = pendingManager.items!
                List(items, id: \.self) { item in
                    VStack {
                        Text(item)
                            .font(.system(size: 14, design: .monospaced))
                    }
                }
                    .navigationTitle("Pending")
                    .navigationBarItems(
                        leading: Button(action: self.showSidebar, label: {
                            Image(systemName: "line.3.horizontal")
                        }),
                        trailing: Button(action: {
                            pendingManager.update()
                        }, label: {
                            Image(systemName: "arrow.clockwise")
                        }))
            }
        }
    }
    
    init(_showSidebar: @escaping () -> Void, pending: PendingManager) {
        self.showSidebar = _showSidebar
        self.pendingManager = pending
    }
}
