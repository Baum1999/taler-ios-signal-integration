/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
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
    @Binding var soundPlayed: Bool

#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0       // extension mustn't define this, so it must be here
    @AppStorage("playSoundsI") var playSoundsI: Int = 1             // extension mustn't define this, so it must be here
    @AppStorage("playSoundsB") var playSoundsB: Bool = false

    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
        ViewState.shared.popToRootView(nil)
    }
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if controller.backendState == .ready {
                Content(logger: logger, stack: stack.push("Content"), talerFontIndex: $talerFontIndex)
                    .onAppear() {
#if DEBUG
                        if playSoundsI != 0  && playSoundsB && !soundPlayed {
                            controller.playSound(1008)     // Startup chime
                        }
#endif
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
        .sheet(isPresented: $model.showError) {
            model.setError(nil)
        } content: {
            if let error2 = model.error2 {
                ErrorSheet(data: error2, devMode: developerMode) {
                    model.setError(nil)
                }.interactiveDismissDisabled()
            }
        }
    } // body
}
// MARK: - TabBar
enum Tab {
    case balances
    case overview
    case settings
}

// MARK: - Content
extension MainView {
    struct Content: View {
        let logger: Logger
        let stack: CallStack
        @Binding var talerFontIndex: Int

#if DEBUG
        @AppStorage("developerMode") var developerMode: Bool = true
#else
        @AppStorage("developerMode") var developerMode: Bool = false
#endif
        @AppStorage("minimalistic") var minimalistic: Bool = false
        @EnvironmentObject private var controller: Controller
        @EnvironmentObject private var model: WalletModel
        @EnvironmentObject private var viewState: ViewState     // popToRootView()
        @EnvironmentObject private var viewState2: ViewState2     // popToRootView()

        @State private var shouldReloadBalances = 0
        @State private var shouldReloadPending = 0
        @State private var balances: [Balance] = []
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false
        @State private var kycURI: URL?


        private var openKycButton: some View {
            Button("KYC") {
                showKycAlert = false
                if let kycURI {
                    UIApplication.shared.open(kycURI)
                } else {
                    // YIKES!
                }
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
                    // User tapped on the tab twice == Pop to root view
                    switch tappedTab {
                        case .balances:
                            ViewState.shared.popToRootView(nil)
//                        case .exchanges:
//                            ViewState2.shared.popToRootView(nil)
                        default:
                            break
                    }
//                    if homeNavigationStack.isEmpty {
                        //User already on home view, scroll to top
//                    } else {
//                        homeNavigationStack = []
//                    }
                } else {    // Set the tab to the tabbed tab
                    self.selectedTab = tappedTab
                }
            }
        }

        var body: some View {
#if PRINT_CHANGES
            // "@self" marks that the view value itself has changed, and "@identity" marks that the
            // identity of the view has changed (that is, that the persistent data associated with
            // the view has been recycled for a new instance of the same type)
            if #available(iOS 17.1, *) {
                // logs at INFO level, “com.apple.SwiftUI” subsystem, category “Changed Body Properties”
                let _ = Self._logChanges()
            } else {
                let _ = Self._printChanges()
            }
            let delay: UInt = 0     // set to 5 to test delayed currency information
#else
            let delay: UInt = 0     // no delay for release builds
#endif
            let balancesTitle = String(localized: "TitleBalances", defaultValue: "Balances")
            let overviewTitle = String(localized: "TitleOverview", defaultValue: "Overview")
            let settingsTitle = String(localized: "TitleSettings", defaultValue: "Settings")
          Group {
//            let labelStyle = minimalistic ? IconOnlyLabelStyle() : TitleAndIconLabelStyle()    // labelStyle doesn't work
            TabView(selection: tabSelection()) {
                NavigationView {
                    BalancesListView(stack: stack.push(balancesTitle),
                                  navTitle: balancesTitle,
                                  balances: $balances,
//                       shouldReloadPending: $shouldReloadPending,
                      shouldReloadBalances: $shouldReloadBalances)
                }.id(viewState.rootViewId)                // any change to rootViewId triggers popToRootView behaviour
                .navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")             // iOS will automatically use filled variant
                        .accessibilityLabel(balancesTitle)
                    if !minimalistic { Text(balancesTitle) }
                }
                .tag(Tab.balances)
                .badge(0)         // TODO: set badge if transaction finished in background
                if balances.count > 1 {
                    NavigationView {
                        OverviewListV(stack: stack.push(overviewTitle),
                                     navTitle: overviewTitle,
                                     balances: $balances,
//                        shouldReloadPending: $shouldReloadPending,
                         shouldReloadBalances: $shouldReloadBalances)
                    }.id(viewState2.rootViewId)                // any change to rootViewId triggers popToRootView behaviour
                    .navigationViewStyle(.stack)
                    .tabItem {
                        Image(systemName: "dollarsign")
                            .accessibilityLabel(overviewTitle)
                        if !minimalistic { Text(overviewTitle) }
                    }
                    .tag(Tab.overview)
                }
                NavigationView {
                    SettingsView(stack: stack.push(),
                              balances: $balances,
                              navTitle: settingsTitle)
                }.navigationViewStyle(.stack)
                .tabItem {
                    Image(systemName: "gear")                   // system will automatically use filled variant
                        .accessibilityLabel(settingsTitle)
                    if !minimalistic { Text(settingsTitle) }
                }
                .tag(Tab.settings)
            }
//            .animation(.linear(duration: LAUNCHDURATION), value: selectedTab)     doesn't work. Needs CustomTabView
          } .onNotification(.KYCrequired) { notification in
              // show an alert with the KYC link (button) which opens in Safari
                if let transition = notification.userInfo?[TRANSACTIONTRANSITION] as? TransactionTransition {
                    if let kycString = transition.experimentalUserData {
                        if let urlForKYC = URL(string: kycString) {
                            logger.log(".onNotification(.KYCrequired): \(kycString)")
                            kycURI = urlForKYC
                            showKycAlert = true
                        }
                    } else {
                        // TODO: no KYC URI
                    }
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
            .onNotification(.TransactionExpired) { notification in
                // reload balances on receiving TransactionExpired notification ...
                logger.info(".onNotification(.TransactionExpired) ==> reload")
                shouldReloadBalances += 1
                shouldReloadPending += 1
            }
            .onNotification(.TransactionDone) {
                shouldReloadBalances += 1
                shouldReloadPending += 1
                selectedTab = .balances
            }
            .onNotification(.TransactionError) { notification in
                shouldReloadPending += 1
            }
            .onNotification(.Error) { notification in
                if let error = notification.userInfo?[NOTIFICATIONERROR] as? Error {
                    model.setError(error)
                    controller.playSound(0)
                }
            }
            .onChange(of: balances) { newArray in
                for balance in newArray {
                    let scope = balance.scopeInfo
                    if controller.hasInfo(for: scope.currency) == nil {
                        Task { // runs on MainActor
                            if let info = try? await model.getCurrencyInfoM(scope: scope, delay: delay) {
                                await controller.setInfo(info)
                            }
                        }
                    }
                }
            }
        } // body
    } // Content
}
