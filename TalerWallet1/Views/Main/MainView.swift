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
    private let symLog = SymLogV(0)
    let stack: CallStack
    @EnvironmentObject private var viewState: ViewState         // popToRootView()
    @EnvironmentObject private var controller: Controller
    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil
    @Binding var soundPlayed: Bool
    @AppStorage("talerFont") var talerFont: Int = 0         // extension mustn't define this, so it must be here

    func sheetDismissed() -> Void {
        symLog.log("sheet dismiss")
    }
    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if controller.backendState == .ready {
                Content(symLog: symLog, stack: stack.push(), talerFont: $talerFont)
                // any change to rootViewId triggers popToRootView behaviour
                    .id(viewState.rootViewId)
                    .onAppear() {
                        controller.playSound(1008)     // Startup chime
                        soundPlayed = true
                    }
            } else if controller.backendState == .error {
                ErrorView(errortext: nil)            // TODO: show Error View
            } else {
                LaunchAnimationView()
            }
        }
        .animation(.linear(duration: LAUNCHDURATION), value: controller.backendState)
        .overlay(alignment: .top) {
            // Show the viewID on top of the app's NavigationView
            DebugViewV()
                .id("ViewID")
        }
        .onOpenURL { url in
            symLog.log(".onOpenURL: \(url)")
            // will be called on a taler:// scheme either
            // by user tapping such link in a browser (bank website)
            // or when launching the app from iOS Camera.app scanning a QR code
            urlToOpen = url     // raise sheet
        }
        .sheet(item: $urlToOpen, onDismiss: sheetDismissed) { url in
            let sheet = AnyView(URLSheet(stack: stack.push(), urlToOpen: url))
            Sheet(sheetView: sheet)
        }
    } // body
}
// MARK: - Content
extension MainView {
    struct Content: View {
        let symLog: SymLogV?
        let stack: CallStack
        @Binding var talerFont: Int
        @State var sidebarVisible: Bool = false
        func hamburgerAction() {
            withAnimation(.easeInOut(duration: 0.25)) {
                sidebarVisible = !sidebarVisible
            }
        }

        let balances = String(localized: "Balances")
        let exchanges = String(localized: "Exchanges")
        let settings = String(localized: "Settings")
        var views: [SidebarItem] {[
            SidebarItem(name: balances,
                    sysImage: "creditcard.fill",        // TODO: Wallet Icon
                        view: AnyView(BalancesListView(stack: stack.push(balances),
                                                    navTitle: balances,
                                             hamburgerAction: hamburgerAction)
                                     )),
            SidebarItem(name: exchanges,
                    sysImage: "building.columns",
                        view: AnyView(ExchangeListView(stack: stack.push(exchanges),
                                                    navTitle: exchanges,
                                             hamburgerAction: hamburgerAction)
                                     )),
            SidebarItem(name: settings,    // TODO: "About"?
                    sysImage: "gearshape.fill",
                        view: AnyView(SettingsView(navTitle: settings,
                                            hamburgerAction: hamburgerAction)
                                     ))
        ]}
        @State var currentView: Int = 0

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            ZStack(alignment: .leading) {
                NavigationView {   // the one and only for all non-sheet views
                    VStack(alignment: .leading) {   // only needed for backslide transition
                        views[currentView].view
                            .id(views[currentView].name)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .transition(.backslide)
                    }   .id(talerFont)
                        .navigationBarTitleDisplayMode(.automatic)
                        .background(NavigationBarBuilder { navigationController in
                            //                            navigationController.navigationBar.barTintColor = .red
                            navigationController.navigationBar.titleTextAttributes =
                                [.font: TalerFont.talerFont(talerFont, size: 24, relativeTo: .title2)]
                            navigationController.navigationBar.largeTitleTextAttributes =
                                [.font: TalerFont.talerFont(talerFont, size: 38, relativeTo: .largeTitle)]
                        })
                }
                .navigationViewStyle(.stack)
                .talerNavBar(talerFont: talerFont)

                // The side view is above (Z-Axis) the current view
                SideBarView(stack: stack.push(),
                            views: views,
                      currentView: $currentView,
                   sidebarVisible: sidebarVisible,
                  hamburgerAction: hamburgerAction)
            }
        }
    } // Content
}
