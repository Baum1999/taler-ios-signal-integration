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

extension URL: Identifiable {
    public var id: URL {self}
}

struct ContentView: View {
    private let symLog = SymLogV()
    @EnvironmentObject private var controller: Controller
    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil

    var body: some View {
        if controller.backendState == .ready {
            symLog {
                Content(symLog: symLog, controller: controller)
                    .onAppear {     // called e.g. after coming to foreground
                        symLog.log(".onAppear")
                    }
                    .onOpenURL { url in
    // TODO: check if this is called when launching the app from the camera scanning a QR code
                        symLog.log(".onOpenURL: \(url)")
                        urlToOpen = url
                    }
                    .sheet(item: $urlToOpen, onDismiss: {}) { url in
                        URLSheet(urlToOpen: url)
                    }
            } // symLog
        } else if controller.backendState == .error {
            ErrorView()            // TODO: show Error View
        } else {
            LaunchAnimationView()
        }
    }
}
// MARK: - Content
extension ContentView {
    struct Content: View {
        let symLog: SymLogV?
        var controller: Controller

        @State var sidebarVisible: Bool = false
        @State var currentView: Int = 0
        var views: [SidebarItem] {[
            SidebarItem(name: "Balances",
                        sysImage: "creditcard.fill",        // TODO: Wallet Icon
                        view: AnyView(CurrenciesListView(viewModel: controller.balancesModel)
                                      { sidebarVisible = true }
                                     )),
            SidebarItem(name: "Settings",
                        sysImage: "gearshape.fill",
                        view: AnyView(SettingsView()
                                      { sidebarVisible = true }
                                     )),
            SidebarItem(name: "Pending Operations",
                        sysImage: "arrow.triangle.2.circlepath",
                        view: AnyView(PendingOpsListView(viewModel: controller.pendingModel)
                                      { sidebarVisible = true }
                                     ))
        ]}
        var body: some View {
            ZStack(alignment: .leading) {
                views[currentView].view
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                SideBarView(views: views, currentView: $currentView, sidebarVisible: $sidebarVisible)
            }
                .background(Color(.systemGray6))
        }
    }
}
// MARK: -
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView.Content(symLog: nil, controller: controller)
//    }
//}
