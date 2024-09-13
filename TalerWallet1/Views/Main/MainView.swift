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

    @State private var balances: [Balance] = []
    @State private var selectedBalance: Balance? = nil
    @State private var sheetPresented = false
    @State private var urlToOpen: URL? = nil
    @State private var showQRScanner: Bool = false
    @State private var showCameraAlert: Bool = false

    func sheetDismissed() -> Void {
        logger.info("sheet dismiss")
        ViewState.shared.popToRootView(nil)
    }

    private var openSettingsButton: some View {
        Button("Open Settings") {
            showCameraAlert = false
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    let ClosingAnnouncement = AttributedString(localized: "Closing Camera")
    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            if #available(iOS 17.0, *) {
                AccessibilityNotification.Announcement(ClosingAnnouncement).post()
            }
            showCameraAlert = false
        }
    }
    private func dismissingSheet() {
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(ClosingAnnouncement).post()
        }
    }

    var defaultPriorityAnnouncement = AttributedString(localized: "Opening Camera")
    var lowPriorityAnnouncement: AttributedString {
        var lowPriorityString = AttributedString ("Camera Loading")
        if #available(iOS 17.0, *) {
            lowPriorityString.accessibilitySpeechAnnouncementPriority = .low
        }
        return lowPriorityString
    }
    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString("Camera Active")
        if #available(iOS 17.0, *) {
            highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        }
        return highPriorityString
    }
    private func checkCameraAvailable() -> Void {
        // Open Camera when QR-Button was tapped
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(defaultPriorityAnnouncement).post()
        }
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                showQRScanner = true            // present sheet
                if #available(iOS 17.0, *) {
                    AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                }
            } else {
                showCameraAlert = true
            }
        })
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if controller.backendState == .ready {
                Content(logger: logger, stack: stack.push("Content"),
                      balances: $balances,
               selectedBalance: $selectedBalance,
                talerFontIndex: $talerFontIndex,
                  cameraAction: checkCameraAvailable)
                    .onAppear() {
#if DEBUG
                        if playSoundsI != 0  && playSoundsB && !soundPlayed {
                            controller.playSound(1008)     // Startup chime
                        }
#endif
                        soundPlayed = true
                    }
                    .alert("Scanning QR-codes requires access to the camera",
                           isPresented: $showCameraAlert,
                               actions: {   openSettingsButton
                                            dismissAlertButton },
                               message: {   Text("Please allow camera access in settings.") }) // Scanning QR-codes
                    .sheet(isPresented: $showQRScanner, onDismiss: dismissingSheet) {
                        let sheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                                                 balances: $balances,
                                          selectedBalance: $selectedBalance))
                        Sheet(stack: stack.push(), sheetView: sheet)
                    } // sheet
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
                                      balances: $balances,
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
//            case .overview: return String(localized: "TitleOverview", defaultValue: "Overview")
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
            case .balances: return Image(systemName: "chart.bar.xaxis")
            case .actions:  return Image(logo)
//            case .overview: return Image(systemName: "dollarsign")
            case .settings: return Image(systemName: "gear")
        }
    }

}

// MARK: - Content
extension MainView {
    struct Content: View {
        let logger: Logger
        let stack: CallStack
        @Binding var balances: [Balance]
        @Binding var selectedBalance: Balance?
        @Binding var talerFontIndex: Int
        let cameraAction: () -> Void

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
        @State private var selectedTab: Tab = .balances
        @State private var showKycAlert: Bool = false
        @State private var kycURI: URL?

        @State private var showActionSheet = false
        @State private var sheetHeight: CGFloat = .zero
        @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
        @State private var summary: String = ""
        @State private var showSpendingHint = true
        @State private var actionSelected: Int? = nil
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
            let tabBarView = TabBarView(selection: $selectedTab) {
                if selectedTab != .balances {
                    selectedTab = .balances
                }
                // TODO: check NavigationStack, pop only if necessary
//                ViewState.shared.popToRootView(nil)   either do this after any of the buttons was operated, or don't do it at all
                showActionSheet = true
            }

            let scope = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange,
                                noFees: false,
                                   url: DEMOEXCHANGE,
                              currency: DEMOCURRENCY)

            let sendDest = SendAmountV(stack: stack.push("\(Self.className())()"),
                                    balances: balances,
                             selectedBalance: $selectedBalance,             // if nil shows currency picker
                            amountToTransfer: $amountToTransfer,            // currency needs to be updated!
                                     summary: $summary,
                                   scopeInfo: scope,
                                cameraAction: cameraAction)

            let requestDest = RequestPayment(stack: stack.push("\(Self.className())()"),
                                          balances: balances,
                                   selectedBalance: $selectedBalance,
                                  amountToTransfer: $amountToTransfer,      // currency needs to be updated!
                                           summary: $summary,
                                         scopeInfo: scope,
                                      cameraAction: cameraAction)

            let depositDest = DepositIbanV(stack: stack.push(),
                                        balances: balances,
                                 selectedBalance: $selectedBalance,
                                        feeLabel: nil,
                                    feeIsNotZero: nil,
                //                   depositIBAN: $depositIBAN,
                //                 accountHolder: $accountHolder,
                                amountToTransfer: $amountToTransfer)

            let manualWithdrawDest = ManualWithdraw(stack: stack.push(),
                                                 balances: balances,
                                          selectedBalance: $selectedBalance,
                                                  isSheet: false,
                                                scopeInfo: scope,
                                                 exchange: $myExchange,
                                         amountToTransfer: $amountToTransfer)

            ZStack(alignment: .bottom) {
                TabView(selection: tabSelection()) {
                    NavigationView {
                        BalancesListView(stack: stack.push(balancesTitle),
                                      balances: $balances,
                               selectedBalance: $selectedBalance,
//                         shouldReloadPending: $shouldReloadPending,
                          shouldReloadBalances: $shouldReloadBalances,
                                  cameraAction: cameraAction)
                        .navigationTitle(balancesTitle)
                        .background( Group {
                            NavigationLink(destination: sendDest, tag: 1, selection: $actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: requestDest, tag: 2, selection: $actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: depositDest, tag: 3, selection: $actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                            NavigationLink(destination: manualWithdrawDest, tag: 4, selection: $actionSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        })
                        .onNotification(.SendAction) { actionSelected = 1 }
                        .onNotification(.RequestAction) { actionSelected = 2 }
                        .onNotification(.DepositAction) { actionSelected = 3 }
                        .onNotification(.WithdrawAction) { actionSelected = 4 }
                    }.id(viewState.rootViewId)                // any change to rootViewId triggers popToRootView behaviour
                    .navigationViewStyle(.stack)
                    .tag(Tab.balances)

                    EmptyView().tag(Tab.actions)

                    NavigationView {
                        SettingsView(stack: stack.push(),
                                  balances: $balances,
                                  navTitle: settingsTitle)
                    }.id(viewState2.rootViewId)               // any change to rootViewId triggers popToRootView behaviour
                    .navigationViewStyle(.stack)
                    .tag(Tab.settings)
                } // TabView
//                    .ignoresSafeArea(.keyboard, edges: .bottom)
//                    .padding(.bottom, 10)
                tabBarView
//                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
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
            .sheet(isPresented: $showActionSheet) {
                let content = VStack {
                    ActionsSheet(stack: stack.push(),
                              balances: $balances,
                      showSpendingHint: $showSpendingHint,
                      amountToTransfer: $amountToTransfer,
                               summary: $summary,
                          cameraAction: cameraAction)
                    .padding(.bottom, 32)
                }
                if #available(iOS 16, *) {
                    content.fixedInnerHeight($sheetHeight)
                } else {
                    content
                }
            }
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
                    controller.checkInfo(for: scope, model: model)
                }
            }
        } // body
    } // Content
}
