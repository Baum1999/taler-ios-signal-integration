/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

// Use this to delay instantiation when using `NavigationLink`, etc...
struct LazyView<Content: View>: View {
    var content: () -> Content
    var body: some View {
        self.content()
    }
}

struct MainView: View {
    private let symLog = SymLogV()
    @EnvironmentObject private var viewState: ViewState         // popToRootView()
    @EnvironmentObject private var controller: Controller
    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil

    func sheetDismiss() -> Void {
        symLog.log("sheet dismiss")
    }
    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            NavigationView {   // the one and only for all non-sheet views
                if controller.backendState == .ready {
                    Content(symLog: symLog)
                        // any change to rootViewId triggers popToRootView behaviour
                        .id(viewState.rootViewId)
                        .onOpenURL { url in
                            symLog.log(".onOpenURL: \(url)")
                            // will be called on a taler:// scheme either
                            // by user tapping such link in a browser (bank website)
                            // or when launching the app from iOS Camera.app scanning a QR code
                            urlToOpen = url     // raise sheet
                        }
                } else if controller.backendState == .error {
                    ErrorView(errortext: nil)            // TODO: show Error View
                } else {
                    LaunchAnimationView()
                }
            }.navigationViewStyle(.stack)
            .overlay(alignment: .top) {
                // Show the viewID on top of the app's NavigationView
                DebugViewV()
                    .id("ViewID")
            }
            .sheet(item: $urlToOpen, onDismiss: sheetDismiss) { url in
                let sheet = AnyView(URLSheet(urlToOpen: url))
                Sheet(sheetView: sheet)
            }
    } // body
}
// MARK: - Content
extension MainView {
    struct Content: View {
        let symLog: SymLogV?

        @State var sidebarVisible: Bool = false
        @State var currentView: Int = 0

        var views: [SidebarItem] {[
            SidebarItem(name: String(localized: "Balances"),
                    sysImage: "creditcard.fill",        // TODO: Wallet Icon
                        view: AnyView(BalancesListView(model: BalancesModel.model(currency: "*"))
                                      { sidebarVisible = !sidebarVisible }     // hamburgerAction
                                     )),
            SidebarItem(name: String(localized: "Exchanges"),
                    sysImage: "building.columns",
                        view: AnyView(ExchangeListView(model: ExchangeModel.model())
                                      { sidebarVisible = !sidebarVisible }     // hamburgerAction
                                     )),
            SidebarItem(name: String(localized: "Settings"),    // TODO: "About"?
                    sysImage: "gearshape.fill",
                        view: AnyView(SettingsView()
                                      { sidebarVisible = !sidebarVisible }     // hamburgerAction
                                     ))
        ]}
        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            ZStack(alignment: .leading) {
                views[currentView].view
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .id(views[currentView].name)
                    .transition(.backslide)
                SideBarView(views: views, currentView: $currentView, sidebarVisible: $sidebarVisible)
            }
                .background(WalletColors().backgroundColor)
        }
    }
}
