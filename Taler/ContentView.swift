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

struct SidebarItem {
    var name: String
    var view: AnyView
}

struct ContentView: View {
    @StateObject var backend: BackendManager = BackendManager()
    
    @State var sidebarVisible: Bool = false
    var views: [SidebarItem] {[
        SidebarItem(name: "Main",
            view: AnyView(Button { [self] in
                self.sidebarVisible = true
            } label: {
                Text("Open Sidebar")
            })),
        SidebarItem(name: "Settings",
            view: AnyView(SettingsView {
                self.sidebarVisible = true
            }.environmentObject(backend)))
    ]}
    @State var currentView: Int = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            views[currentView].view
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack {
                Spacer()
                
                Button {
                    self.sidebarVisible = false
                } label: {
                    Text("Close")
                }
                Divider()
                
                ForEach(0..<views.count, id: \.self) { i in
                    Button {
                        self.sidebarVisible = false
                        self.currentView = i
                    } label: {
                        Text(views[i].name)
                    }
                    Divider()
                }
                
                Spacer()
            }
                .background(Color.gray)
                .frame(width: 100, alignment: .center)
                .offset(x: sidebarVisible ? 0 : -100)
                .animation(.easeInOut, value: sidebarVisible)
                .ignoresSafeArea()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
