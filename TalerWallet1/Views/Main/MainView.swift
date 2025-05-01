/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 * @author Iván Ávalos
 */
import SwiftUI
import os.log
import SymLog
import AVFoundation
import taler_swift

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

    @StateObject var tabBarModel = TabBarModel()
    @State private var selectedBalance: Balance? = nil              // gets set in TransactionsListView
    @State private var selectedIndex: Int? = nil                    // user selects savings box in OIMview
    @State private var urlToOpen: URL? = nil
    @State private var showUrlSheet = false
    @State private var showActionSheet = false
    @State private var showScanner = false
//    @State private var showCameraAlert: Bool = false
    @State private var qrButtonTapped = false
    @State private var qrButton2Tapped = false
    @State private var innerHeight: CGFloat = .zero
    @State private var userAction = 0

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
        symLog.log("sheet dismiss: \(urlToOpen)")
        urlToOpen = nil
        ViewState.shared.popToRootView(nil)
    }

    private func dismissingSheet() {
//        if #available(iOS 17.0, *) {
//            AccessibilityNotification.Announcement(ClosingAnnouncement).post()
//        }
    }
    private func dismissScanner() {
        showActionSheet = false
        qrButtonTapped = false
        qrButton2Tapped = false
        userAction += 1
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let mainContent = ZStack {
            MainContent(logger: logger, stack: stack.push("Content"),
               selectedBalance: $selectedBalance,
                 selectedIndex: $selectedIndex,                     // user selects savings box in OIMview
                talerFontIndex: $talerFontIndex,
               showActionSheet: $showActionSheet,
                   showScanner: $showScanner,
                qrButtonTapped: $qrButtonTapped,
                    userAction: $userAction)
            .onAppear() {
#if DEBUG
                if playSoundsI != 0  && playSoundsB && !soundPlayed {
                    controller.playSound(1008)
                }
#endif
                soundPlayed = true
            }                   // Startup chime
            .overlay(alignment: .top) {
                DebugViewV()
                    .id("ViewID")
            }     // Show the viewID on top of the app's NavigationView

            if (!showScanner && urlToOpen == nil) {
                if let error2 = model.error2 {
                    ErrorView(data: error2, devMode: developerMode) {
                        model.setError(nil)
                    }.interactiveDismissDisabled()
                    .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
//                   .transition(.move(edge: .top))
//                } else {
//                    Color.clear
                }
            }
        }//.transition(.move(edge: .top))

        let mainGroup = Group {
            // show launch animation until either ready or error
            switch controller.backendState {
                case .ready: mainContent
                case .error: ErrorView(title: "",   // TODO: String(localized: ""),
                                    copyable: true) {}
                default:     LaunchAnimationView()
            }
        }.animation(.linear(duration: LAUNCHDURATION), value: controller.backendState)

        Group {
            mainGroup
                .environmentObject(tabBarModel)
//            .animation(.default, value: model.error2 == nil)
                .sheet(isPresented: $showUrlSheet, onDismiss: sheetDismissed) {
                    let sheet = URLSheet(stack: stack.push(),
                               selectedBalance: selectedBalance,
                                     urlToOpen: $urlToOpen)
                        .id("onOpenURL")
                    Sheet(stack: stack.push(), sheetView: AnyView(sheet))
                }
                .sheet(isPresented: $showScanner,
                         onDismiss: dismissScanner
                ) {
                    let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                                        selectedBalance: selectedBalance))
//                    let _ = logger.trace("❗️showScanner: \(SCANDETENT)❗️")
                    if #available(iOS 16.4, *) {
                        let scanDetent: PresentationDetent = .fraction(SCANDETENT)
                        Sheet(stack: stack.push(), sheetView: qrSheet)
                            .presentationDetents([scanDetent])
                            .transition(.opacity)
                    } else {
                        Sheet(stack: stack.push(), sheetView: qrSheet)
                            .transition(.opacity)
                    }
                }
                .sheet(isPresented: $showActionSheet,
                       onDismiss: { showScanner = false
                                    qrButtonTapped = false
                                    qrButton2Tapped = false
                                    userAction += 1 }
                ) {
                    if #available(iOS 16.4, *) {
//                        let _ = logger.trace("❗️actionsSheet: small❗️ (showScanner == false)")
                        if #available(iOS 18.3, *) {
                            DualHeightSheet(stack: stack.push(),
                                  selectedBalance: selectedBalance,
                                   qrButtonTapped: $qrButton2Tapped,
                                   dismissScanner: dismissScanner)
                        } else {
                            DualHeightSheet(stack: stack.push(),
                                  selectedBalance: selectedBalance,
                                   qrButtonTapped: $qrButtonTapped,
                                   dismissScanner: dismissScanner)
                        }
                    } else {
                        Group {
                            Spacer(minLength: 1)
                            ScrollView {
                                ActionsSheet(stack: stack.push(),
                                    qrButtonTapped: $qrButtonTapped)
                                .innerHeight($innerHeight)
//                              .padding()
                            }
                            .frame(maxHeight: innerHeight)
                            .edgesIgnoringSafeArea(.all)
                        }
                        .background(WalletColors().gray2)
                    } // iOS 15
                }
        }
#if OIM
        .onRotate { newOrientation in
            let isSheetActive = showActionSheet || showScanner || showUrlSheet
            controller.setOIMmode(for: newOrientation, isSheetActive)
            tabBarModel.oimActive = controller.oimModeActive ? 1 : 0
        }
#endif
        .onOpenURL { url in
            symLog.log(".onOpenURL: \(url)")
            // will be called on a taler:// scheme either
            // by user tapping such link in a browser (bank website)
            // or when launching the app from iOS Camera.app scanning a QR code
            urlToOpen = url
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showUrlSheet = true     // raise sheet
            }
        }
        .onChange(of: qrButtonTapped) { tapped in
            if tapped {
                let delay = if #available(iOS 16.4, *) { 0.5 } else { 0.01 }
                withAnimation(Animation.easeOut(duration: 0.5).delay(delay)) {
                    showScanner = true      // switch to qrSheet => camera on
        }   }   }
    } // body
}
// MARK: - TabBar
enum Tab: Int, Hashable, CaseIterable {
    case balances = 0
    case actions
    case settings

//    var index: Int { self.rawValue }

    var title: String {
        switch self {
            case .balances: String(localized: "TitleBalances", defaultValue: "Balances")
            case .actions:  String(localized: "TitleActions", defaultValue: "Actions")
            case .settings: String(localized: "TitleSettings", defaultValue: "Settings")
        }
    }

    var image: Image {
#if TALER_WALLET
        let logo = "taler-logo-2023-blue"
#elseif TALER_NIGHTLY
        let logo = "taler-logo-2023-black"
#else   // GNU_TALER
        let logo = "taler-logo-2023-red"
#endif
        switch self {
            case .balances: return Image(systemName: BALANCES)                  // 􀣉  "chart.bar.xaxis"
            case .actions:  return Image(logo)
            case .settings: return Image(systemName: SETTINGS)                  // 􀍟 "gear"
        }
    }

    var a11y: String {
        switch self {
            case .balances: BALANCES                                            // 􀣉  "chart.bar.xaxis"
            case .actions:  "bolt"
            case .settings: SETTINGS                                            // 􀍟 "gear"
        }
    }

    var label: Label<Text, Image> {
        Label(self)
    }
}
// MARK: -
class NamespaceWrapper: ObservableObject {
    var namespace: Namespace.ID

    init(_ namespace: Namespace.ID) {
        self.namespace = namespace
    }
}
// MARK: -
extension Label where Title == Text, Icon == Image {
    init(_ tab: Tab) {
        self.init(EMPTYSTRING, systemImage: tab.a11y)
    }
}
// MARK: - Content
struct ActionType: Hashable {
    let animationDisabled: Bool
}
// MARK: - Content
extension MainView {

    struct MainContent: View {
        let logger: Logger
        let stack: CallStack
        @Binding var selectedBalance: Balance?
        @Binding var selectedIndex: Int?                            // user selects savings box in OIMview
        @Binding var talerFontIndex: Int
        @Binding var showActionSheet: Bool
        @Binding var showScanner: Bool
        @Binding var qrButtonTapped: Bool
        @Binding var userAction: Int

        @EnvironmentObject private var controller: Controller
        @EnvironmentObject private var model: WalletModel
        @EnvironmentObject private var tabBarModel: TabBarModel
        @EnvironmentObject private var viewState: ViewState     // popToRootView()
        @EnvironmentObject private var viewState2: ViewState2     // popToRootView()
#if DEBUG
        @AppStorage("developerMode") var developerMode: Bool = true
#else
        @AppStorage("developerMode") var developerMode: Bool = false
#endif
        @AppStorage("minimalistic") var minimalistic: Bool = false

        @State private var shouldReloadBalances = 0
        @State private var shouldReloadTransactions = 0
        @State private var shouldReloadPending = 0
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false
        @State private var kycURI: URL?

        @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)  // Update currency when used
        @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
        @State private var summary: String = EMPTYSTRING
        @State private var exchange: Exchange? = nil

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
                        case .settings:
                            ViewState2.shared.popToRootView(nil)
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
        private var isBalances: Bool { self.selectedTab == .balances}
        private func triggerAction(_ action: Int) {
            tabBarModel.actionSelected = isBalances ? action        // 1..4
                                                    : action + 4    // 5..8
        }

        private static func className() -> String {"\(self)"}
        private static var name: String { Self.className() }

        private var tabContent: some View {
            /// Destinations for the 4 actions
            let sendDest = SendAmountV(stack: stack.push(Self.name),
                             selectedBalance: selectedBalance,                  // if nil shows currency picker
                               selectedIndex: selectedIndex,                    // selected savings box from OIMview
                              amountLastUsed: $amountLastUsed,                  // currency needs to be updated!
                                     summary: $summary)
            let requestDest = RequestPayment(stack: stack.push(Self.name),
                                   selectedBalance: selectedBalance,
                                   selectedIndex: selectedIndex,                // selected savings box from OIMview
                                    amountLastUsed: $amountLastUsed,            // currency needs to be updated!
                                           summary: $summary)
            let depositDest = DepositSelectV(stack: stack.push(Self.name),
                                   selectedBalance: selectedBalance,
                                    amountLastUsed: $amountLastUsed)
            let manualWithdrawDest = ManualWithdraw(stack: stack.push(Self.name),
                                          selectedBalance: selectedBalance,
                                           amountLastUsed: $amountLastUsed,     // currency needs to be updated!
                                         amountToTransfer: $amountToTransfer,
                                                 exchange: $exchange,           // only for withdraw-exchange
                                                  isSheet: false)
            /// each NavigationView needs its own NavLinks
            let balanceActions = Group {                                        // actionSelected will hide the tabBar
                NavLink(1, $tabBarModel.actionSelected) { sendDest }
                NavLink(2, $tabBarModel.actionSelected) { requestDest }
                NavLink(3, $tabBarModel.actionSelected) { depositDest }
                NavLink(4, $tabBarModel.actionSelected) { manualWithdrawDest }
            }
            let settingsActions = Group {
                NavLink(5, $tabBarModel.actionSelected) { sendDest }
                NavLink(6, $tabBarModel.actionSelected) { requestDest }
                NavLink(7, $tabBarModel.actionSelected) { depositDest }
                NavLink(8, $tabBarModel.actionSelected) { manualWithdrawDest }
            }
            /// tab titles, and invisible tabItems which are only used for a11y
            let balancesTitle = Tab.balances.title     // "Balances"
            let actionTitle = Tab.actions.title        // "Actions"
            let settingsTitle = Tab.settings.title     // "Settings"
            let a11yBalanceTab = Label(Tab.balances).labelStyle(.titleOnly)
                                    .accessibilityLabel(balancesTitle)
            let a11yActionsTab = Label(Tab.actions).labelStyle(.titleOnly)
                                    .accessibilityLabel(actionTitle)
            let a11ySettingsTab = Label(Tab.settings).labelStyle(.titleOnly)
                                    .accessibilityLabel(settingsTitle)
            /// NavigationViews for Balances & Settings
            let balancesStack = NavigationView {
                BalancesListView(stack: stack.push(balancesTitle),
                       selectedBalance: $selectedBalance,                       // <= gets set in TransactionsListView
                         selectedIndex: $selectedIndex,                 // user selects savings box in OIMview
//                   shouldReloadPending: $shouldReloadPending,
                    reloadTransactions: $shouldReloadTransactions,
                        qrButtonTapped: $qrButtonTapped)
                .navigationTitle(balancesTitle)
                .background(balanceActions)
            }.navigationViewStyle(.stack)
            let settingsStack = NavigationView {
                SettingsView(stack: stack.push(),
                          navTitle: settingsTitle)
                .background(settingsActions)
            }.navigationViewStyle(.stack)
            /// the tabItems (EMPTYSTRING .titleOnly) could indeed be omitted and the app would work the same - but are needed for accessibilityLabel
            return TabView(selection: tabSelection()) {
                balancesStack.id(viewState.rootViewId)      // change rootViewId to trigger popToRootView behaviour
                    .tag(Tab.balances)
                    .tabItem { a11yBalanceTab }
                Color.clear                                 // can't use EmptyView: VoiceOver wouldn't have the Actions tab
                    .tag(Tab.actions)
                    .tabItem { a11yActionsTab }
                settingsStack.id(viewState2.rootViewId)     // change rootViewId to trigger popToRootView behaviour
                    .tag(Tab.settings)
                    .tabItem { a11ySettingsTab }
            } // TabView
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

            // custom tabBar with the Actions button in the middle
            let tabBarView = TabBarView(selection: tabSelection(), userAction: $userAction, hidden: $tabBarModel.tabBarHidden) {
                logger.log("onActionTab")
                showActionSheet = true
            } onActionDrag: {
                logger.log("onActionDrag: showScanner = true")
                showScanner = true
            }

            ZStack(alignment: .bottom) {
                tabContent              // incl. the (transparent) SwiftUI tabBar
                tabBarView              // custom tabBar is rendered on top of the TabView, and overlaps its tabBar
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .accessibilityHidden(true)                  // for a11y we use the original tabBar, not our custom one
            } // ZStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onNotification(.SendAction)    { notification in
                if let actionType = notification.userInfo?[NOTIFICATIONANIMATION] as? ActionType {
                    if actionType.animationDisabled {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            triggerAction(1)
                        }
                    } else { triggerAction(1) }
                } else { triggerAction(1) }
            }
            .onNotification(.RequestAction) { triggerAction(2) }
            .onNotification(.DepositAction) { triggerAction(3) }
            .onNotification(.WithdrawAction){ triggerAction(4) }
            .onNotification(.KYCrequired) { notification in
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
            .alert("You need to pass a KYC procedure.",
                 isPresented: $showKycAlert,
                 actions: {   openKycButton
                              dismissAlertButton },
                 message: {   Text("Tap the button to go to the KYC website.") })
            .onNotification(.BalanceChange) { notification in
                logger.info(".onNotification(.BalanceChange) ==> reload balances")
                shouldReloadBalances += 1
            }
            .onNotification(.TransactionExpired) { notification in
                logger.info(".onNotification(.TransactionExpired) ==> reload balances")
                shouldReloadTransactions += 1
                shouldReloadPending += 1
            }
            .onNotification(.TransactionDone) {
                shouldReloadTransactions += 1
                shouldReloadPending += 1
//                selectedTab = .balances       // automatically switch to Balances
            }
            .onNotification(.TransactionError) { notification in
                shouldReloadPending += 1
            }
            .onNotification(.GeneralError) { notification in
                if let error = notification.userInfo?[NOTIFICATIONERROR] as? Error {
                    model.setError(error)
                    controller.playSound(0)
                }
            }
            .task(id: shouldReloadBalances) {
//                symLog.log(".task shouldReloadBalances \(shouldReloadBalances)")
                await controller.loadBalances(stack.push("refreshing balances"), model)
            } // task
        } // body
    } // Content
}
