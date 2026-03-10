/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var biometricService: BiometricService

#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0       // extension mustn't define this, so it must be here
    @AppStorage("playSoundsI") var playSoundsI: Int = 1             // extension mustn't define this, so it must be here
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("useAuthentication") var useAuthentication: Bool = false

    @StateObject private var tabBarModel = TabBarModel()
    @State private var selectedBalance: Balance? = nil      // for sheets, gets set in TransactionsListView
    @State private var urlToOpen: URL? = nil
    @State private var showUrlSheet = false
    @State private var showActionSheet = false              // Action button tapped
    @State private var showScanner = false
//    @State private var showCameraAlert: Bool = false
    @State private var qrButtonTapped = false
    @State private var qrButton2Tapped = false
    @State private var scannedCode: Bool = false
    @State private var innerHeight: CGFloat = .zero
    @State private var userAction = 0                       // make Action button jump, hold here
    @State private var networkUnavailable = false
    @State private var backgrounded: Date?                  // time we go into background

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
        symLog.log("sheet dismiss: \(urlToOpen)")
        urlToOpen = nil
        ViewState.shared.popToRootView(nil)
    }

    private func dismissSheet() {
        showScanner = false
        showActionSheet = false
        qrButtonTapped = false
        qrButton2Tapped = false
        scannedCode = false
        userAction += 1
        // TODO: wallet-core could notify us when it creates a dialog tx
        NotificationCenter.default.post(name: .TransactionScanned, object: nil, userInfo: nil)
    }

    func hintApplicationResumed() {
        Task.detached {
            await model.hintApplicationResumedT()
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let mainContent = ZStack {
            MainContent(logger: logger, stack: stack.push("Content"),
               selectedBalance: $selectedBalance,
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
                    ErrorView(stack.push("Main"), data: error2, devMode: developerMode) {
                        model.setError(nil)
                    }.interactiveDismissDisabled()
                    .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
//                   .transition(.move(edge: .top))
//                } else {
//                    Color.clear
                }
            }
        }
            .overlay {
                if useAuthentication && !biometricService.isAuthenticated {
                    Color.gray.opacity(0.75)
                        .animation(.easeInOut, value: biometricService.isAuthenticated)
                    if let errorMessage = biometricService.authenticationError {
                        Text(errorMessage)
                            .talerFont(.title)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(WalletColors().backgroundColor)
                            .onTapGesture {
                                biometricService.authenticationError = nil
                                biometricService.authenticateUser()
                            }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    biometricService.authenticationError = nil
                                    if !biometricService.canAuthenticate {
                                        let _ = print("authentication not available")
                                        useAuthentication = false           // switch off
                                    }
                                }
                            }
                    } else {
                        Image(TALER_LOGO)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .onAppear {
                                biometricService.authenticateUser()
                            }
                            .onTapGesture {
                                biometricService.authenticateUser()
                            }
                    }
                }
            }

        let mainGroup = Group {
            // show launch animation until either ready or error
            switch controller.backendState {
                case .ready: mainContent
                case .error: ErrorView(stack.push("mainGroup"),
                                       title: EMPTYSTRING,   // TODO: String(localized: ""),
                                    copyable: true) {}
                default:     LaunchAnimationView()
            }
        }.animation(.linear(duration: LAUNCHDURATION), value: controller.backendState)

        VStack {
            if networkUnavailable {
                Text("Network unavailable!")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.red)
                    }
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top),
                        removal: .move(edge: .top)
                    ))
            }

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
                         onDismiss: dismissSheet
                ) {
                    let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                                        selectedBalance: selectedBalance,
                                       scannedSomething: $scannedCode))
//                    let _ = logger.trace("❗️showScanner: \(SCANDETENT)❗️")
                    if #available(iOS 16.4, *) {
                        let detent: PresentationDetent = .fraction(scannedCode ? ACTIONDETENT
                                                                : minimalistic ? SCANDETENT : ACTIONDETENT)
                        Sheet(stack: stack.push(), sheetView: qrSheet)
                            .presentationDetents([detent])
                            .transition(.opacity)
                    } else {
                        Sheet(stack: stack.push(), sheetView: qrSheet)
                            .transition(.opacity)
                    }
                }
                .sheet(isPresented: $showActionSheet,
                       onDismiss: dismissSheet
                ) {
                    if #available(iOS 16.4, *) {
//                        let _ = logger.trace("❗️actionsSheet: small❗️ (showScanner == false)")
                        if #available(iOS 18.0, *) {
                            DualHeightSheet(stack: stack.push(),
                                  selectedBalance: selectedBalance,
                                   qrButtonTapped: $qrButton2Tapped,
                                   dismissScanner: dismissSheet)        // needs to explicitely dismiss 2nd sheet
                        } else {
                            DualHeightSheet(stack: stack.push(),
                                  selectedBalance: selectedBalance,
                                   qrButtonTapped: $qrButtonTapped,
                                   dismissScanner: {})//dismissSheet)
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
        .onChange(of: showScanner) { newShowScan in
            let isSheetActive = showActionSheet || showScanner || showUrlSheet
            controller.setOIMmode(for: UIDevice.current.orientation, isSheetActive)
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
        .onChange(of: controller.talerURI) { url in
            if url != nil {
                urlToOpen = url
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    controller.talerURI = nil
                    showUrlSheet = true     // raise sheet
        }   }   }

        .onChange(of: qrButtonTapped) { tapped in
            if tapped {
                let delay = if #available(iOS 16.4, *) { 0.5 } else { 0.01 }
                withAnimation(Animation.easeOut(duration: 0.5).delay(delay)) {
                    showScanner = true      // switch to qrSheet => camera on
        }   }   }
        .onChange(of: controller.isConnected) { isConnected in
            if isConnected {
                withAnimation(.easeIn(duration: 1.0)) {
                    networkUnavailable = false
                }
            } else {
                withAnimation(.easeOut(duration: 1.0)) {
                    networkUnavailable = true
        }   }   }

        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification, object: nil)) { _ in
            logger.log("❗️App Will Resign")
            backgrounded = Date.now
            showScanner = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification, object: nil)) { _ in
            logger.log("❗️App Will Enter Foreground")
            if let backgrounded {
                let interval = Date.now - backgrounded
                if interval.seconds > 60 {
                    biometricService.isAuthenticated = false
                    if interval.seconds > 300 {     // 5 minutes
                        logger.log("More than 5 minutes in background - tell wallet-core")
                        hintApplicationResumed()
                    }
                }
            }
            backgrounded = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: nil)) { _ in
            logger.log("❗️App Did Become Active")
        }

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
        switch self {
            case .balances: return Image(systemName: BALANCES)                  // 􀣉  "chart.bar.xaxis"
            case .actions:  return Image(TALER_LOGO)
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
// MARK: -
struct ActionType: Hashable {
    let animationDisabled: Bool
}
// MARK: - Content
extension MainView {

    struct MainContent: View {
        let logger: Logger
        let stack: CallStack
        @Binding var selectedBalance: Balance?
        @Binding var talerFontIndex: Int
        @Binding var showActionSheet: Bool
        @Binding var showScanner: Bool
        @Binding var qrButtonTapped: Bool
        @Binding var userAction: Int            // make Action button jump

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
        @AppStorage("oimEuro") var oimEuro: Bool = false

        @State private var shouldReloadBalances = 0
        @State private var shouldReloadTransactions = 0
//        @State private var shouldReloadPending = 0
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false
        @State private var kycURI: URL?

        @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)  // Update currency when used
        @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
        @State private var summary: String = EMPTYSTRING
        @State private var iconID: String? = nil

        private var openKycButton: some View {
            Button("Legitimization") {
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
                             selectedBalance: $selectedBalance,                 // if nil shows currency picker
                              amountLastUsed: $amountLastUsed,                  // currency needs to be updated!
                                     summary: $summary,
                                      iconID: $iconID,
                                     oimEuro: oimEuro)
            let requestDest = RequestPayment(stack: stack.push(Self.name),
                                   selectedBalance: selectedBalance,
                                    amountLastUsed: $amountLastUsed,            // currency needs to be updated!
                                           summary: $summary,
                                            iconID: $iconID,
                                           oimEuro: oimEuro)
            let depositDest = DepositSelectV(stack: stack.push(Self.name),
                                   selectedBalance: selectedBalance,
                                    amountLastUsed: $amountLastUsed)
            let manualWithdrawDest = ManualWithdraw(stack: stack.push(Self.name),
                                                      url: nil,
                                          selectedBalance: selectedBalance,
                                           amountLastUsed: $amountLastUsed,     // currency needs to be updated!
                                         amountToTransfer: $amountToTransfer,
                                                 exchange: nil,                 // only for withdraw-exchange
                                      maySwitchCurrencies: true,
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
                                 title: balancesTitle,
                       selectedBalance: $selectedBalance,    // needed for sheets, gets set in TransactionsListView
                    reloadTransactions: $shouldReloadTransactions,
                        qrButtonTapped: $qrButtonTapped)
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

        func onActionTab() {
            logger.log("onActionTab: showActionSheet = true")
            controller.removeURLs(after: 60*60)         // TODO: specify time after which scanned URLs are deleted
            showActionSheet = true
        }

        func onActionDrag() {
            logger.log("onActionDrag: showScanner = true")
            showScanner = true
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
#endif
            // custom tabBar with the Actions button in the middle
            let tabBarView = TabBarView(selection: tabSelection(),
                                       userAction: $userAction,
                                           hidden: $tabBarModel.tabBarHidden,
                                      onActionTab: onActionTab,
                                     onActionDrag: onActionDrag)
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
            .alert("You need to pass a legitimization procedure.",
                 isPresented: $showKycAlert,
                 actions: {   openKycButton
                              dismissAlertButton },
                 message: {   Text("Tap the button to go to the legitimization website.") })
            .onNotification(.BalanceChange) { notification in
                logger.info(".onNotification(.BalanceChange) ==> reload balances")
                shouldReloadBalances += 1
            }
            .onNotification(.TransactionExpired) { notification in
                logger.info(".onNotification(.TransactionExpired) ==> reload balances")
                shouldReloadTransactions += 1
//                shouldReloadPending += 1
            }
            .onNotification(.TransactionScanned) {
                shouldReloadTransactions += 1
            }
            .onNotification(.TransactionDone) {
                shouldReloadTransactions += 1
//                shouldReloadPending += 1
//                selectedTab = .balances       // automatically switch to Balances
            }
            .onNotification(.TransactionError) { notification in
//                shouldReloadPending += 1
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
