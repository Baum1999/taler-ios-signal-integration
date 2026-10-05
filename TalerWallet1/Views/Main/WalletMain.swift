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

// MARK: -
struct ActionType: Hashable {
    let animationDisabled: Bool
}
// MARK: - Content

struct WalletMain: View {
    let logger: Logger
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var talerFontIndex: Int
#if TALER_NIGHTLY
    @Binding var sheetType: SheetType?
#else
    @Binding var showActionSheet: Bool
    @Binding var showScanner: Bool
#endif
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var tabBarModel: TabBarModel
    @EnvironmentObject private var viewState: ViewState     // popToRootView()
    @EnvironmentObject private var viewState2: ViewState2     // popToRootView()
    @EnvironmentObject private var wrapper: NamespaceWrapper
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("tapped") var tapped: Int = 0
    @AppStorage("oimEuro") var oimEuro: Bool = false

    @State private var shouldReloadBalances = 0
    @State private var shouldReloadTransactions = 0
    @State private var selectedTab: TalerTab = .balances
    @State private var showKycAlert: Bool = false
    @State private var kycURI: URL?

    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)  // Update currency when used
    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary: String = EMPTYSTRING
    @State private var iconID: String? = nil
    @State private var showRealCashHint = true

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

//    @available(iOS, deprecated: 26.0)
    // \|/ this doesn't work - should give a compiler warning when called from 26+, but doesn't
    @available(iOS, obsoleted: 26.0)
    private func tabSelection() -> Binding<TalerTab> {
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
                    case .actions:
                        if #available(iOS 26.0, *) {
                            logger.log(level: .debug, "TODO: show Action sheet again if it's not active already")

                        } else {
                            break
                        }
                }
//                if homeNavigationStack.isEmpty {
                    // User already on home view, scroll to top
//                } else {
                    // pop to root
//                    homeNavigationStack = []
//                }
            } else {    // Set the tab to the tabbed tab
                self.selectedTab = tappedTab
                if #available(iOS 26.0, *) {
                    if tappedTab == .actions {
                        logger.log(level: .debug, "TODO: show Action sheet")

                    }
                } // else the custom tabBar will handle the Action sheet
            }
        }
    }

    private var isBalances: Bool { self.selectedTab == .balances}
    private func triggerAction(_ action: Int) {
        tabBarModel.actionSelected = action < 0 ? action
                                   : isBalances ? action        // 1..4
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
        /// tab titles
        let balancesTitle = TalerTab.balances.title     // "Balances"
        let actionTitle = TalerTab.actions.title        // "Actions"
        let settingsTitle = TalerTab.settings.title     // "Settings"
                                                        /// each NavigationView needs its own NavLinks
        let balanceActions = Group {                                        // actionSelected will hide the tabBar
            NavLink(1, $tabBarModel.actionSelected) { sendDest }
            NavLink(2, $tabBarModel.actionSelected) { requestDest }
            NavLink(3, $tabBarModel.actionSelected) { depositDest }
            NavLink(4, $tabBarModel.actionSelected) { manualWithdrawDest }
            if #available(iOS 26.0, *) {
                NavLink(-1, $tabBarModel.actionSelected) {
                    SettingsView(stack: stack.push(),
                                 navTitle: settingsTitle)
                }
            }
        }
        let settingsActions = Group {
            NavLink(5, $tabBarModel.actionSelected) { sendDest }
            NavLink(6, $tabBarModel.actionSelected) { requestDest }
            NavLink(7, $tabBarModel.actionSelected) { depositDest }
            NavLink(8, $tabBarModel.actionSelected) { manualWithdrawDest }
        }
        /// NavigationViews for Balances & Settings
        let balancesStack = NavigationView {
            ZStack(alignment: .trailing) {
                if controller.balances.isEmpty {
                    WalletEmptyHeader(stack: stack.push(), showRealCashHint: $showRealCashHint)
                } else {
//                    if #available(iOS 17.0, *) {
//                        CarouselView(stack: stack.push(balancesTitle),
//                           selectedBalance: $selectedBalance,    // needed for sheets, gets set in TransactionsListView
//                        reloadTransactions: $shouldReloadTransactions)
//                    } else {   // Fallback on earlier versions
                    BalancesListView(stack: stack.push(balancesTitle),
                                     title: balancesTitle,
                           selectedBalance: $selectedBalance,    // needed for sheets, gets set in TransactionsListView
                          showRealCashHint: $showRealCashHint,
                        reloadTransactions: $shouldReloadTransactions)
                    .accessibilitySortPriority(1) // Reads third
//                    } iOS 15 + 16
                }
                if #available(iOS 26.0, *) {
                    // floating Settings & Action buttons
                    let buttons = VStack(alignment: .trailing) {
                        if voiceOverEnabled {
                            SettingsButton26(sortPriority: 0)
                        }
                        Spacer()
                        ActionItem(stack: stack.push(),
                                     tab: TalerTab.actions,
                                   onTap: onActionTab,
                                  onDrag: onActionDrag)
                        .accessibilitySortPriority(2) // Reads second
                        .matchedTransitionSource(id: "unique_transition_id", in: wrapper.namespace)
//                        .navigationTransition(.zoom(sourceID: "unique_transition_id", in: wrapper.namespace))
                    }
                        .padding(.horizontal)
#if OIM
                    if !controller.oimModeActive {  // hide for OIM
                        buttons
                    }
#else
                    buttons
#endif
                } // iOS 26
            }.background(balanceActions)

        }.navigationViewStyle(.stack)
            .accessibilitySortPriority(3) // Reads first

        if #available(iOS 26.0, *) {
            // no TabView, just a single NavigationView, containing the BalancesListView
            // with floating Liquid Glass Actions button
            return balancesStack.id(viewState.rootViewId)      // change rootViewId to trigger popToRootView behaviour
        } else {
            // iOS 15..18: TabView with 3 tabs, middle is Actions
            let settingsStack = NavigationView {
                SettingsView(stack: stack.push(),
                          navTitle: settingsTitle)
                .background(settingsActions)
            }.navigationViewStyle(.stack)
            /// invisible tabItems, used for a11y
            let a11yBalanceTab = TalerTab.balances.label
                .accessibilityLabel(balancesTitle)
                .labelStyle(.titleOnly)
            let a11yActionsTab = Label(TalerTab.actions)
                .accessibilityLabel(actionTitle)
                .labelStyle(.titleOnly)
            let a11ySettingsTab = Label(TalerTab.settings)
                .accessibilityLabel(settingsTitle)
                .labelStyle(.titleOnly)
            return TabView(selection: tabSelection()) {
                balancesStack.id(viewState.rootViewId)      // change rootViewId to trigger popToRootView behaviour
                    .tag(TalerTab.balances)
                    .tabItem { a11yBalanceTab }
                Color.clear                                 // can't use EmptyView: VoiceOver wouldn't have the Actions tab
                    .tag(TalerTab.actions)
                    .tabItem { a11yActionsTab }
                settingsStack.id(viewState2.rootViewId)     // change rootViewId to trigger popToRootView behaviour
                    .tag(TalerTab.settings)
                    .tabItem { a11ySettingsTab }
            } // TabView
        }
    }

    func onActionTab() {
        logger.log("onActionTab: showActionSheet = true")
        controller.removeURLs(after: 60*60)         // TODO: specify time after which scanned URLs are deleted
        withAnimation {
#if TALER_NIGHTLY
            sheetType = .action
#else
            showActionSheet = true
#endif
        }
    }

#if TALER_NIGHTLY
    var showScanner: Bool { sheetType == .scanner }
#endif
    func onActionDrag(_ stack: CallStack) {
        if !showScanner {                           // gets called multiple times - log only once
#if DEBUG
            if let caller = stack.peek() {
                logger.log("showScanner = true (onActionDrag: \(caller.file):\(caller.function))")
            }
#endif
            withAnimation {
#if TALER_NIGHTLY
                sheetType = .scanner
#else
                showScanner = true
#endif
            }
        }
    }

    func tabBarView() -> some View {
        // iOS 15..18: custom tabBar (with Actions button) is rendered on top of the TabView,
        // and overlays the native iOS tabBar (which is still used for VoiceOver)
        TabBarView(stack: stack.push(),
               selection: tabSelection(),
                  hidden: $tabBarModel.tabBarHidden,
             onActionTab: onActionTab,
            onActionDrag: onActionDrag)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityHidden(true)                  // for a11y we use the original tabBar, not our custom one
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
        ZStack(alignment: .bottom) {
            tabContent              // incl. the (transparent) SwiftUI tabBar
            if #unavailable(iOS 26.0) {
                tabBarView()
            }
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
        .onNotification(.SettingsAction){ triggerAction(-1) }
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
        .onNotification(.ShareAction){ notification in
            if let actionData = notification.userInfo?[NOTIFICATIONSHARE] as? ShareType {
                let textToShare = actionData.textToShare
                let image = actionData.image
                ShareSheet.shareSheet(textToShare: textToShare, image: image)
            }
        }
        .alert("You need to pass a legitimization procedure.",
               isPresented: $showKycAlert,
               actions: {   openKycButton
                            dismissAlertButton },
               message: {   Text("Tap the button to go to the legitimization website.") })
        .onNotification(.BalanceChange) { notification in
            logger.info(".onNotification(.BalanceChange) ==> reload balances")
//            if let date = notification.userInfo?[NOTIFICATIONTIME] as? Date {
//
//            }
            shouldReloadBalances += 1
        }
        .onNotification(.TransactionDeleted) { notification in
            logger.info(".onNotification(.TransactionDeleted) ==> reload balances")
            shouldReloadTransactions += 1
        }
        .onNotification(.TransactionExpired) { notification in
            logger.info(".onNotification(.TransactionExpired) ==> reload balances")
            shouldReloadTransactions += 1
        }
        .onNotification(.TransactionScanned) {
            shouldReloadTransactions += 1
        }
        .onNotification(.TransactionDone) {
            shouldReloadTransactions += 1
//            selectedTab = .balances       // automatically switch to Balances
        }
        .onNotification(.TransactionError) { notification in
//          TODO:      reload pending ??
        }
        .onNotification(.GeneralError) { notification in
            if let error = notification.userInfo?[NOTIFICATIONERROR] as? Error {
                model.setError(error)
                controller.playSound(0)
            }
        }
        .task(id: shouldReloadBalances) {   // runs once at launch, then on each onNotification(.BalanceChange)
//            symLog.log(".task shouldReloadBalances \(shouldReloadBalances)")
            await controller.loadBalances(stack.push("refreshing balances"))
            await controller.loadDiscounts(stack.push("refreshing discounts"))
            await controller.loadSubscriptions(stack.push("refreshing passes"))
        } // task
    } // body
} // Content

