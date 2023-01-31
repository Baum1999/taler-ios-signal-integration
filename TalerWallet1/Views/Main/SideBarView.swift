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

fileprivate let sidebarWidth = 250.0

struct SidebarItem {
    var name: String
    var sysImage: String?
    var view: AnyView
}

struct SideBarView: View {
    private let symLog = SymLogV(0)
    var views: [SidebarItem]
    @Binding var currentView: Int
    @Binding var sidebarVisible: Bool

    var body: some View {
        symLog {
            HStack {
                VStack {
                    Spacer()
                    ForEach(0..<views.count, id: \.self) { i in
                        Button {
                            symLog.log("sidebar item \"\(views[i].name)\" selected")
                            sidebarVisible = false      // slide sidebar to the left
                            currentView = i             // switch to the view the user selected
                        } label: {
                            if let sysImage = views[i].sysImage {
                                Label(views[i].name, systemImage: sysImage)
                                    .frame(maxWidth: sidebarWidth, alignment: .leading)
                            } else {
                                Text(views[i].name)
                                    .frame(maxWidth: sidebarWidth)
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.title)
//                        .padding(.vertical)

//                        Divider()
                    }
                    Spacer()
                    Spacer()
                }
                .background(Color(.systemGray5))
                .frame(width: sidebarWidth, alignment: .center)
                // TODO: use leading instead of sidebarWidth for right-to-left
                .offset(x: sidebarVisible ? 0 : -sidebarWidth)
                .animation(.easeInOut, value: sidebarVisible)
                .ignoresSafeArea()
                //  .onAppear can NOT be used here, because we don't show or dismiss this view,
                //   but only slide it left or right - so it is always there.
                //   .onAppear {}    would be called once even before LaunchScreen is dismissed and then never again

                // this is just a target for a tap gesture outside the sidebar to dismiss it
                Color.clear
                    .frame(maxWidth: sidebarVisible ? .infinity : 0, maxHeight: .infinity, alignment: .leading)
                    // TODO: right-to-left ?
                    .offset(x: sidebarVisible ? sidebarWidth : 0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        sidebarVisible = false
                    }
            }
        }
    }
}

#if DEBUG
struct BindingViewContainer : View {
    @State var currentView: Int = 0
    @State var sidebarVisible: Bool = true
    var views: [SidebarItem]

    var body: some View {
        ZStack(alignment: .leading) {
            views[currentView].view
            SideBarView(views: views, currentView: $currentView, sidebarVisible: $sidebarVisible)
        }
    }
}

struct SideBarView_Previews: PreviewProvider {
    static var views: [SidebarItem] {[
        SidebarItem(name: "Balances",
                    view: AnyView(WalletEmptyView())),
        SidebarItem(name: "Settings",
                    view: AnyView(WalletEmptyView()))
    ]}
    static var previews: some View {
        BindingViewContainer(views: views)
    }
}
#endif
