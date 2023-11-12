/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import os.log
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
    let logger: Logger
    let stack: CallStack
    @EnvironmentObject private var viewState: ViewState         // popToRootView()
    @EnvironmentObject private var controller: Controller
    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil
    @Binding var soundPlayed: Bool
    @AppStorage("talerFont") var talerFont: Int = 0         // extension mustn't define this, so it must be here
    @AppStorage("playSounds") var playSounds: Int = 1       // extension mustn't define this, so it must be here

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
    }
    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if controller.backendState == .ready {
                Content(logger: logger, stack: stack.push("Content"), talerFont: $talerFont)
                // any change to rootViewId triggers popToRootView behaviour
                    .id(viewState.rootViewId)
                    .onAppear() {
                        if playSounds != 0  && !soundPlayed {
                            controller.playSound(1008)     // Startup chime
                        }
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
// MARK: - TabBar
enum Tab {
    case balances, exchanges, settings
}

// MARK: - Content
extension MainView {
    struct Content: View {
        let logger: Logger
        let stack: CallStack
        @State private var shouldReloadBalances = 0
        @State private var balances: [Balance] = []
        @Binding var talerFont: Int
        @AppStorage("iconOnly") var iconOnly: Bool = false
        @EnvironmentObject private var controller: Controller
        @EnvironmentObject private var model: WalletModel
        let balancesTitle = String(localized: "TitleBalances", defaultValue: "Balances")
        let exchangesTitle = String(localized: "TitleExchanges", defaultValue: "Exchanges")
        let settingsTitle = String(localized: "TitleSettings", defaultValue: "Settings")
#if TABBAR  // Taler Wallet
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false

        private var openKycButton: some View {
            Button("KYC") {
                showKycAlert = false
//                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        }
        private var dismissAlertButton: some View {
            Button("Cancel", role: .cancel) {
                showKycAlert = false
            }
        }

        private func tabSelection() -> Binding<Tab> {
            Binding { //this is the get block
                self.selectedTab
            } set: { tappedTab in
                if tappedTab == self.selectedTab {
                    //User tapped on the tab twice == Pop to root view
//                    if homeNavigationStack.isEmpty {
                        //User already on home view, scroll to top
//                    } else {
//                        homeNavigationStack = []
//                    }
                }
                //Set the tab to the tabbed tab
                self.selectedTab = tappedTab
            }
        }
#else       // GNU Taler
        @State var sidebarVisible: Bool = false
        func hamburgerAction() {
            withAnimation(.easeInOut(duration: 0.25)) {
                sidebarVisible = !sidebarVisible
            }
        }

        var views: [SidebarItem] {[
            SidebarItem(name: balancesTitle,
                    sysImage: "chart.bar.xaxis",  // creditcard.fill     // TODO: Wallet Icon
                        view: AnyView(BalancesListView(stack: stack.push(balancesTitle),
                                                    navTitle: balancesTitle,
                                                    balances: $balances,
                                        shouldReloadBalances: $shouldReloadBalances,
                                             hamburgerAction: hamburgerAction)
                                     )),
            SidebarItem(name: exchangesTitle,
                    sysImage: "building.columns",
                        view: AnyView(ExchangeListView(stack: stack.push(exchangesTitle),
//                                                    balances: $balances,
                                                    navTitle: exchangesTitle,
                                             hamburgerAction: hamburgerAction)
                                     )),
            SidebarItem(name: settingsTitle,    // TODO: "About"?
                    sysImage: "gearshape.fill",
                        view: AnyView(SettingsView(stack: stack.push(settingsTitle),
                                                navTitle: settingsTitle,
                                         hamburgerAction: hamburgerAction)
                                     ))
        ]}
        @State var currentView: Int = 0
#endif

        var body: some View {
#if DEBUG
            // "@self" marks that the view value itself has changed, and "@identity" marks that the
            // identity of the view has changed (that is, that the persistent data associated with
            // the view has been recycled for a new instance of the same type)
//            if #available(iOS 17.1, *) {
//                // logs at INFO level, “com.apple.SwiftUI” subsystem, category “Changed Body Properties”
//                let _ = Self._logChanges()
//            } else {
                let _ = Self._printChanges()
//            }
            let delay: UInt = 5
#else
            let delay: UInt = 0
#endif
          Group {
#if TABBAR  // Taler Wallet
//            let labelStyle = iconOnly ? IconOnlyLabelStyle() : TitleAndIconLabelStyle()    // labelStyle doesn't work
            TabView(selection: tabSelection()) {
                NavigationView {
                    BalancesListView(stack: stack.push(balancesTitle),
                                  navTitle: balancesTitle,
                                  balances: $balances,
                      shouldReloadBalances: $shouldReloadBalances)
                }.navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")             // creditcard     system will automatically use filled variant
                        .accessibilityLabel(balancesTitle)
                    if !iconOnly { Text(balancesTitle) }
                }
                .tag(Tab.balances)
                .badge(0)         // TODO: set badge if transaction finished in background

                NavigationView {
                    ExchangeListView(stack: stack.push(exchangesTitle),
                                  balances: $balances,
                                  navTitle: exchangesTitle)
                }.navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "building.columns")
                        .accessibilityLabel(exchangesTitle)
                    if !iconOnly { Text(exchangesTitle) }
                }
                .tag(Tab.exchanges)

                NavigationView {
                    SettingsView(stack: stack.push(), navTitle: settingsTitle)
                }.navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "gear")                   // system will automatically use filled variant
                        .accessibilityLabel(settingsTitle)
                    if !iconOnly { Text(settingsTitle) }
                }
                .tag(Tab.settings)
            }
//            .animation(.linear(duration: LAUNCHDURATION), value: selectedTab)     doesn't work. Needs CustomTabView
#else       // GNU Taler
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
                                [.font: TalerFont.uiFont(talerFont, size: 24, relativeTo: .title2)]
                            navigationController.navigationBar.largeTitleTextAttributes =
                                [.font: TalerFont.uiFont(talerFont, size: 38, relativeTo: .largeTitle)]
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
#endif
          } .onNotification(.TransactionStateTransition) { notification in
              // show an alert with the KYC link (button) which opens in Safari
                if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                    if transition.newTxState.major == .pending {
                        if let newMinor = transition.newTxState.minor {
                            if newMinor == .kyc {       // user did confirm on bank website
                                logger.log(".onNotification(): KYC required")
                                showKycAlert = true
                            }
                        }
                    }
                } else { // should never happen
                    logger.error("Yikes! TransactionStateTransition without transition")
                }
            }
            .alert("You need to pass a KYC procedure",
                 isPresented: $showKycAlert,
                 actions: {   openKycButton
                              dismissAlertButton },
                 message: {   Text("Tap the button to go to the KYC website.") })
            .onNotification(.BalanceChange) { notification in
              // reload balances on receiving BalanceChange notification ...
                logger.info(".onNotification(.BalanceChange) ==> reload")
                shouldReloadBalances += 1
            }
            .onChange(of: balances) { newArray in
                for balance in newArray {
                    let scope = balance.scopeInfo
                    logger.info("balance changed: \(scope.currency, privacy: .public)")
                    if !controller.hasInfo(for: scope.currency) {
                        Task { // runs on MainActor
                            logger.info("Task to get info for: \(scope.currency, privacy: .public)")
                            do {
                                let info = try await model.getCurrencyInfo(scope: scope, delay: delay)
                                logger.info("got info: \(scope.currency, privacy: .public)")
                                await controller.setInfo(info)
                            } catch {    // TODO: error handling - couldn't get CurrencyInfo
                                logger.error("Couldn't get info for: \(scope.currency, privacy: .public)\n\(error)")
                            }
                        }
                    }
                }
            }
        } // body
    } // Content
}
