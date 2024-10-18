/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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

    @State private var selectedBalance: Balance? = nil
    @State private var urlToOpen: URL? = nil
    @State private var sheetPresented = false
    @State private var showActionSheet = false
    @State private var showScanner = false
//    @State private var showCameraAlert: Bool = false
    @State private var qrButtonTapped = false
    @State private var innerHeight: CGFloat = .zero

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
        ViewState.shared.popToRootView(nil)
    }

    private func dismissingSheet() {
//        if #available(iOS 17.0, *) {
//            AccessibilityNotification.Announcement(ClosingAnnouncement).post()
//        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if controller.backendState == .ready {
                Content(logger: logger, stack: stack.push("Content"),
               selectedBalance: $selectedBalance,
                talerFontIndex: $talerFontIndex,
               showActionSheet: $showActionSheet,
                   showScanner: $showScanner)
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
            let sheet = AnyView(URLSheet(stack: stack.push(),
                               selectedBalance: $selectedBalance,
                                     urlToOpen: url))
            Sheet(stack: stack.push(), sheetView: sheet)
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
        .onChange(of: qrButtonTapped) { tapped in
            if tapped {
                let delay = if #available(iOS 16.4, *) { 0.5 } else { 0.01 }
                withAnimation(Animation.easeOut(duration: 0.5).delay(delay)) {
                    showScanner = true      // switch to qrSheet => camera on
        }   }   }
        .sheet(isPresented: $showActionSheet,
               onDismiss: { showScanner = false; qrButtonTapped = false }
        ) {
            let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                                          selectedBalance: $selectedBalance))
            if #available(iOS 16.4, *) {
                if showScanner {
                    let _ = logger.log("❗️showScanner: .large❗️")
                    Sheet(stack: stack.push(), sheetView: qrSheet)
                        .presentationDetents([.large])
                        .transition(.opacity)
                } else {
                    let _ = logger.log("❗️actionsSheet: small❗️")
                    DualHeightSheet(stack: stack.push(),
                           qrButtonTapped: $qrButtonTapped)
                }
            } else {
                if showScanner {
                    Sheet(stack: stack.push(), sheetView: qrSheet)
                        .transition(.opacity)
                } else {
                    Group {
                        Spacer()
                        ScrollView {
                            ActionsSheet(stack: stack.push(),
                                qrButtonTapped: $qrButtonTapped)
                            .innerHeight($innerHeight)
//                          .padding()
                        }
                        .frame(maxHeight: innerHeight)
                        .edgesIgnoringSafeArea(.all)
                    }
                    .background(WalletColors().gray2)
                }
            }
        }
    } // body
}
// MARK: - TabBar
enum Tab: String, Hashable, CaseIterable {
    case balances
    case actions
//    case overview
    case settings

    var index: Int {
        switch self {
            case .balances: return 0
            case .actions:  return 1
//            case .overview: return 1
            case .settings: return 2
        }
    }

    var title: String {
        switch self {
            case .balances: return String(localized: "TitleBalances", defaultValue: "Balances")
            case .actions:  return String(localized: "TitleActions", defaultValue: "Actions")
            case .settings: return String(localized: "TitleSettings", defaultValue: "Settings")
        }
    }

    var image: Image {
#if TALER_WALLET
        let logo = "taler-logo-2023-blue"
#else       // GNU Taler
        let logo = "taler-logo-2023-red"
#endif
        switch self {
            case .balances: return Image(systemName: BALANCES)                  // 􀣉  "chart.bar.xaxis"
            case .actions:  return Image(logo)
            case .settings: return Image(systemName: SETTINGS)                  // 􀍟 "gear"
        }
    }

}

// MARK: - Content
extension MainView {
    class NavigationModel: ObservableObject {
        @Published var tabBarHidden = 0

        @Published var actionSelected: Int? = nil {
            didSet {
                if actionSelected != nil {
                    tabBarHidden += 1
                } else {
                    tabBarHidden = 0
                }
            }
        }
    }

    struct Content: View {
        let logger: Logger
        let stack: CallStack
        @Binding var selectedBalance: Balance?
        @Binding var talerFontIndex: Int
        @Binding var showActionSheet: Bool
        @Binding var showScanner: Bool

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

        @StateObject var navModel = NavigationModel()

        @State private var shouldReloadBalances = 0
        @State private var shouldReloadPending = 0
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false
        @State private var kycURI: URL?

        @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)  // Update currency when used
        @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
        @State private var summary: String = EMPTYSTRING
        @State private var myExchange: Exchange? = nil

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

        private static func className() -> String {"\(self)"}
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
            let balancesTitle = Tab.balances.title
//            let actionTitle = Tab.actions.title
            let settingsTitle = Tab.settings.title
            let tabBarView = TabBarView(selection: tabSelection(), hidden: $navModel.tabBarHidden) {
                if selectedTab != .balances {
                    selectedTab = .balances
                }
                // TODO: check NavigationStack, pop only if necessary
//                ViewState.shared.popToRootView(nil)   either do this after any of the buttons was operated, or don't do it at all
                showActionSheet = true
            } onActionDrag: {
                showScanner = true
                showActionSheet = true
            }

            let scope = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange,
                                noFees: false,
                                   url: DEMOEXCHANGE,
                              currency: DEMOCURRENCY)

            let sendDest = SendAmountV(stack: stack.push("\(Self.className())()"),
                             selectedBalance: $selectedBalance,             // if nil shows currency picker
                              amountLastUsed: $amountLastUsed,              // currency needs to be updated!
                                     summary: $summary)

            let requestDest = RequestPayment(stack: stack.push("\(Self.className())()"),
                                   selectedBalance: $selectedBalance,
                                    amountLastUsed: $amountLastUsed,      // currency needs to be updated!
                                           summary: $summary)

            let depositDest = DepositIbanV(stack: stack.push(),
                                 selectedBalance: $selectedBalance,
                                        feeLabel: nil,
                                    feeIsNotZero: nil,
                //                   depositIBAN: $depositIBAN,
                //                 accountHolder: $accountHolder,
                                  amountLastUsed: $amountLastUsed)

            let manualWithdrawDest = ManualWithdraw(stack: stack.push(),
                                          selectedBalance: $selectedBalance,
                                                  isSheet: false,
                                                scopeInfo: scope,
                                                 exchange: $myExchange,
                                         amountToTransfer: $amountToTransfer,
                                           amountLastUsed: $amountLastUsed)

            ZStack(alignment: .bottom) {
                TabView(selection: tabSelection()) {
                    NavigationView {
                        BalancesListView(stack: stack.push(balancesTitle),
                               selectedBalance: $selectedBalance,
//                         shouldReloadPending: $shouldReloadPending,
                          shouldReloadBalances: $shouldReloadBalances)
                        .navigationTitle(balancesTitle)
                        .background( Group {
                            NavigationLink(destination: sendDest, tag: 1, selection: $navModel.actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: requestDest, tag: 2, selection: $navModel.actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: depositDest, tag: 3, selection: $navModel.actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: manualWithdrawDest, tag: 4, selection: $navModel.actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        })
                        .onNotification(.SendAction)    { navModel.actionSelected = 1 }
                        .onNotification(.RequestAction) { navModel.actionSelected = 2 }
                        .onNotification(.DepositAction) { navModel.actionSelected = 3 }
                        .onNotification(.WithdrawAction){ navModel.actionSelected = 4 }
                    }.id(viewState.rootViewId)                // any change to rootViewId triggers popToRootView behaviour
                    .navigationViewStyle(.stack)
                    .tag(Tab.balances)

                    EmptyView().tag(Tab.actions)

                    NavigationView {
                        SettingsView(stack: stack.push(),
                                  navTitle: settingsTitle)
                    }.id(viewState2.rootViewId)               // any change to rootViewId triggers popToRootView behaviour
                    .navigationViewStyle(.stack)
                    .tag(Tab.settings)
                } // TabView
//                    .ignoresSafeArea(.keyboard, edges: .bottom)
//                    .padding(.bottom, 10)
                tabBarView
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            } // ZStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
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
            .task(id: shouldReloadBalances) {
//                symLog.log(".task shouldReloadBalances \(shouldReloadBalances)")
                await controller.loadBalances(stack.push("refreshing balances"), model)
            } // task
        } // body
    } // Content
}
