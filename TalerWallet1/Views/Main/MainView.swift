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
    @AppStorage("useAuthentication") var useAuthentication: Bool = false

    @StateObject private var tabBarModel = TabBarModel()
#if TALER_SIGNAL
    // talerlink://-Links (Signal -> Taler); Router hält den offenen Request
    @ObservedObject private var signalLinkRouter = SignalLinkRouter.shared
#endif
    @State private var selectedBalance: Balance? = nil      // for sheets, gets set in TransactionsListView
    @State private var urlToOpen: URL? = nil
#if TALER_NIGHTLY
    @State private var sheetType: SheetType?
#else
    @State private var showUrlSheet = false
    @State private var showActionSheet = false              // Action button tapped
    @State private var showScanner = false
#endif
//    @State private var showCameraAlert: Bool = false
    @State private var scannedCode: Bool = false
    @State private var innerHeight: CGFloat = .zero
    @State private var backgrounded: Date?                  // time we go into background
    @Namespace private var namespace

    func sheetDismissed() -> Void {
        logger.info("sheetDismissed")
        symLog.log("sheet dismiss: \(urlToOpen)")
        urlToOpen = nil
        ViewState.shared.popToRootView(nil)
#if TALER_SIGNAL
        // Sheet ohne Abschluss geschlossen: Rücksprung cancelled zu Signal,
        // falls noch ein peer-Kontext existiert (consume - nach einem ready
        // bleibt kein Kontext mehr, also nie ein doppelter Rücksprung).
        signalLinkRouter.cancelActivePeer()
#endif
    }

    private func dismissSheet() {
        logger.info("dismissSheet")
#if TALER_NIGHTLY
        sheetType = nil
#else
        showScanner = false
        showActionSheet = false
#endif
        scannedCode = false
        controller.userAction += 1                      // make Action button jump
        // TODO: wallet-core could notify us when it creates a dialog tx
        NotificationCenter.default.post(name: .TransactionScanned, object: nil, userInfo: nil)
    }

    private func dismissActionSheet() {
        logger.info("dismissActionSheet")
#if TALER_NIGHTLY
        sheetType = nil
#else
        showActionSheet = false
#endif
        controller.userAction += 1                      // make Action button jump
    }

    /// A sheet is a modal presentation over the whole window, thus it would be shown *above*
    /// the biometrics overlay. Route every sheet through the lock instead, so that nothing
    /// can be presented while the wallet is locked - a sheet asked for while locked stays
    /// pending and is only shown once the user has authenticated.
    private func unlocked(_ isPresented: Binding<Bool>, _ locked: Bool) -> Binding<Bool> {
        Binding(get: { !locked && isPresented.wrappedValue },
                set: { isPresented.wrappedValue = $0 })
    }

    private func unlocked<Item>(_ item: Binding<Item?>, _ locked: Bool) -> Binding<Item?> {
        Binding(get: { locked ? nil : item.wrappedValue },
                set: { item.wrappedValue = $0 })
    }

    func hintApplicationResumed() {
        Task.detached {
            if let result = try? await model.hintApplicationResumedT() {
                if !result.dbReadHealthy {
                    let error = TalerErrorDetail(code: 53,  // GENERIC_DB_FETCH_FAILED
                                                 when: .now(),
                                                 hint: "Can't read from database")
                    await model.setError(WalletBackendError.walletCoreError(error))
                } else if !result.dbWriteHealthy {
                    let error = TalerErrorDetail(code: 52,  // GENERIC_DB_STORE_FAILED
                                                 when: .now(),
                                                 hint: "Can't write to database")
                    await model.setError(WalletBackendError.walletCoreError(error))
                }
            }
        }
    }

    @ViewBuilder func qrSheet() -> some View {
        let qrSheet = AnyView(QRSheet(stack: stack.push(".sheet"),
                            selectedBalance: selectedBalance,
                           scannedSomething: $scannedCode))
//        let _ = logger.trace("❗️showScanner: \(SCANDETENT)❗️")
        if #available(iOS 16.4, *) {
            let detent: PresentationDetent = .fraction(scannedCode ? FULLDETENT
                                                    : minimalistic ? HALFDETENT : FULLDETENT)
            let sheet = Sheet(stack: stack.push(), sheetView: qrSheet)
                .presentationDetents([detent])
                .transition(.opacity)

            if #available(iOS 18.0, *) {
                sheet
                    .navigationTransition(
                        .zoom(sourceID: "unique_transition_id", in: namespace)
                    )
            } else {
                sheet
            }   // iOS 16 + 17
        } else {
            Sheet(stack: stack.push(), sheetView: qrSheet)
                .transition(.opacity)
        } // iOS 15
    }

    @ViewBuilder func actionSheet() -> some View {
        if #available(iOS 16.4, *) {
//            let _ = logger.trace("❗️actionsSheet: small❗️ (showScanner == false)")
            if #available(iOS 18.0, *) {
                DualHeightSheet(stack: stack.push(),
                      selectedBalance: selectedBalance,
                       dismissScanner: dismissSheet)        // needs to explicitely dismiss 2nd sheet
                // TODO: this is commented out because of the weird behavior when switching to the QR scanner.
                // Once we have ONE sheet with different items, enable this again
//                .navigationTransition(
//                    .zoom(sourceID: "unique_transition_id", in: namespace)
//                )
            } else {
                DualHeightSheet(stack: stack.push(),
                      selectedBalance: selectedBalance,
                       dismissScanner: {})//dismissSheet)
            } // iOS 16 + 17
        } else {
            Group {
                Spacer(minLength: 1)    // leave space for VoiceOver dismiss
                ScrollView {
                    ActionsSheet(stack: stack.push())
                        .innerHeight($innerHeight)
                }
                .frame(maxHeight: innerHeight)
                .ignoresSafeArea()
            }.background(WalletColors().gray2)
        } // iOS 15
    }

#if TALER_NIGHTLY
    var showScanner: Bool { sheetType == .scanner }
    var showUrlSheet: Bool { sheetType != nil && sheetType != .scanner && sheetType != .action }

#endif
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let locked = useAuthentication && !biometricService.isAuthenticated
        let mainContent = ZStack {
#if TALER_NIGHTLY
            WalletMain(logger: logger, stack: stack.push("Content"),
              selectedBalance: $selectedBalance,
               talerFontIndex: $talerFontIndex,
                    sheetType: $sheetType)
            .environmentObject(NamespaceWrapper(namespace))
            .overlay(alignment: .top) {
                DebugViewV()
            }     // Show the viewID on top of the app's NavigationView
#else
            WalletMain(logger: logger, stack: stack.push("Content"),
              selectedBalance: $selectedBalance,
               talerFontIndex: $talerFontIndex,
              showActionSheet: $showActionSheet,
                  showScanner: $showScanner)
            .environmentObject(NamespaceWrapper(namespace))
            .overlay(alignment: .top) {
                DebugViewV()
            }     // Show the viewID on top of the app's NavigationView
#endif

            if (!showScanner && urlToOpen == nil) {
                if let error2 = model.error2 {
                    ErrorView(stack.push("Main"), data: error2, devMode: developerMode) {
                        model.setError(nil)
                    }.interactiveDismissDisabled()
                     .background(FullBackground())
//                   .transition(.move(edge: .top))
//              } else {
//                  Color.clear
                }
            }
        }.overlay {
            if locked {
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
                                    print("authentication not available")
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
        }   // biometrics

        let mainGroup = Group {
            // show launch animation until either ready or error
            switch controller.backendState {
                case .ready: mainContent
                case .update: MigrationView()
                case .error(let error):
                    ErrorView(stack.push("mainGroup"),
                              title: String(localized: "Launch error"),
                            message: error.localizedDescription,
                           copyable: true
                    ) {}
                default:     LaunchAnimationView()
            }
        }.animation(.linear(duration: LAUNCHDURATION), value: controller.backendState)

        VStack(spacing: 0) {
            if controller.networkUnavailable {
                ErrorBanner(.networkUnavailable)        // red bar on top
            } else if controller.slowConnection {
                if !showScanner && !showUrlSheet {
                    ErrorBanner(.warning5sec)               // yellow bar on top
                }
            }
            mainGroup
                .environmentObject(tabBarModel)
                .animation(.default, value: model.error2 == nil)
#if TALER_NIGHTLY
                .sheet(item: unlocked($sheetType, locked),
                  onDismiss: sheetDismissed) { sheet in
                    switch sheet {
                        case .action:
                            actionSheet()
                                .environment(\.fromSheet, true)
                        case .scanner:
                            qrSheet()
                                .environmentObject(tabBarModel)
                                .environment(\.fromSheet, true)
                        case .url(let url):
                            let uSheet = URLSheet(stack.push(),
                                        selectedBalance: selectedBalance,
                                               sheetURL: url)
                                .id("onOpenURL")
                            Sheet(stack: stack.push(), sheetView: AnyView(uSheet))
                                .environmentObject(tabBarModel)
                                .environment(\.fromSheet, true)
                    }
                }
#else
                .sheet(isPresented: unlocked($showUrlSheet, locked),
                         onDismiss: sheetDismissed) {
                    let sheet = URLSheet(stack.push(),
                               selectedBalance: selectedBalance,
                                     urlToOpen: $urlToOpen)
                        .id("onOpenURL")
                    Sheet(stack: stack.push(), sheetView: AnyView(sheet))
                        .environmentObject(tabBarModel)
                        .environment(\.fromSheet, true)
                }   // UrlSheet
                .sheet(isPresented: unlocked($showScanner, locked),
                         onDismiss: dismissSheet) {
                    qrSheet()
                        .environmentObject(tabBarModel)
                        .environment(\.fromSheet, true)
                }   // QR Scanner
                .sheet(isPresented: unlocked($showActionSheet, locked),
                         onDismiss: dismissActionSheet) {
                    actionSheet()
                        .environmentObject(tabBarModel)
                        .environment(\.fromSheet, true)
                }   // ActionSheet
#if TALER_SIGNAL
                .sheet(item: unlocked($signalLinkRouter.pending, locked)) { request in
                    // talerlink://compose-* (compose-send aus T3,
                    // compose-refund aus T4, compose-abort aus T5)
                    switch request {
                        case .composeSend(let params):
                            SignalComposeSendView(params: params)
                        case .composeRefund(let originalUri, let ctx):
                            SignalComposeRefundView(originalUri: originalUri, ctx: ctx)
                        case .composeAbort(let uris, let meta, let ctx):
                            SignalComposeAbortView(uris: uris, meta: meta, ctx: ctx)
                        default:
                            SignalLinkPlaceholderView(request: request)
                    }
                }
                // talerlink://pay-* auf eine EIGENE Zahlung: Detail-Sheet mit
                // Abbrechen statt Annehmen-Sheet (T2, Vertrag Abschnitt 6)
                .sheet(item: unlocked($signalLinkRouter.ownPayment, locked),
                       onDismiss: { signalLinkRouter.cancelActivePeer() }) { info in
                    SignalOwnPaymentView(info: info)
                        .environmentObject(tabBarModel)
                }
#endif
        }   // VStack { networkUnavailable + mainGroup }
#if OIM
        // set controller.oimModeActive
        .onRotate { newOrientation in
  #if TALER_NIGHTLY
            let isSheetActive = sheetType != nil
  #else
            let isSheetActive = showActionSheet || showScanner || showUrlSheet
  #endif
            controller.setOIMmode(for: newOrientation, isSheetActive)
            tabBarModel.oimActive = controller.oimModeActive ? 1 : 0
        }
  #if TALER_NIGHTLY
        .onChange(of: sheetType) { newSheetType in
            let isSheetActive = sheetType != nil
            controller.setOIMmode(for: UIDevice.current.orientation, isSheetActive)
            tabBarModel.oimActive = controller.oimModeActive ? 1 : 0
        }
  #else
        .onChange(of: showScanner) { newShowScan in
            let isSheetActive = showActionSheet || showScanner || showUrlSheet
            controller.setOIMmode(for: UIDevice.current.orientation, isSheetActive)
            tabBarModel.oimActive = controller.oimModeActive ? 1 : 0
        }
  #endif
#endif
        .onNotification(.QrScanAction) {
            let delay = if #available(iOS 16.4, *) { 0.3 } else { 0.01 }
            logger.info("QrScanAction notification: showScanner = true")
            withAnimation(Animation.easeOut(duration: 0.5).delay(delay)) {
#if TALER_NIGHTLY
                sheetType = .scanner
#else
                showActionSheet = false
                showScanner = true      // switch to qrSheet => camera on
#endif
        }   }

        .onNotification(.PasteAction) { notification in
            if let notifData = notification.userInfo?[NOTIFICATIONPASTE] as? PasteType {
                symLog.log(".PasteAction: \(notifData)")
                urlToOpen = notifData.pastedURL
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
#if TALER_NIGHTLY
                    sheetType = .url(notifData.pastedURL)
#else
                    showUrlSheet = true     // raise sheet
#endif
        }   }   }

        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            guard let url = userActivity.webpageURL else { return }
            symLog.log(".onContinueUserActivity: \(url)")
            // will be called on https://wallet.taler.net/link#
            urlToOpen = url
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
#if TALER_NIGHTLY
                sheetType = .url(url)
#else
                showUrlSheet = true     // raise sheet
#endif
        }   }

        .onOpenURL { url in
#if TALER_SIGNAL
            // talerlink:// ausschließlich über den Router: parsen, Kontext
            // merken, bei peerAction die bereinigte taler://-URI weitergeben.
            // Die talerlink-URL selbst darf nie als taler:// behandelt oder
            // geloggt werden (Inhaberpapier, Vertrag 2.6).
            if url.scheme?.lowercased() == "talerlink" {
                let _ = SignalLinkRouter.shared.handle(url)
                return
            }
#endif
            symLog.log(".onOpenURL: \(url)")
            // will be called on a taler:// scheme either
            // by user tapping such link in a browser (bank website)
            // or when launching the app from iOS Camera.app scanning a QR code
            urlToOpen = url
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
#if TALER_NIGHTLY
                sheetType = .url(url)
#else
                showUrlSheet = true     // raise sheet
#endif
        }   }

        .onChange(of: controller.talerURI) { url in
            if let url {
                urlToOpen = url
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    controller.talerURI = nil
#if TALER_NIGHTLY
                    sheetType = .url(url)
#else
                    showUrlSheet = true     // raise sheet
#endif
        }   }   }

        .onNotification(.RequestProgressError) { notification in
            if let progress = notification.userInfo?[NOTIFICATIONERROR] as? RequestProgressError {
                withAnimation(.easeIn(duration: BANNERDURATION)) {
                    controller.errorConnection = true
//                    print("❗️❗️❗️  progress.error: \(progress.error.code) ")
                }
        }   }

        .onNotification(.RequestProgressPhase) { notification in
            if let progress = notification.userInfo?[NOTIFICATIONPHASE] as? RequestProgressPhase {
//                print(progress)
                switch progress.phase {
                    case .delayed:
                        withAnimation(.easeOut(duration: BANNERDURATION)) {
                            controller.slowConnection = true
                            controller.stalledConnection = false
                        }
                    case .stalled:
                        withAnimation(.easeIn(duration: BANNERDURATION)) {
                            controller.slowConnection = true
                            controller.stalledConnection = true
                        }
                    default:
                        withAnimation(.easeIn(duration: BANNERDURATION)) {
                            controller.slowConnection = false
                            controller.stalledConnection = false
                        }
        }   }   }

        .onChange(of: controller.isConnected) { isConnected in
            if isConnected {
                withAnimation(.easeIn(duration: BANNERDURATION)) {
                    controller.networkUnavailable = false
                }
            } else {
                withAnimation(.easeOut(duration: BANNERDURATION)) {
                    controller.networkUnavailable = true
        }   }   }

        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification, object: nil)) { _ in
            logger.log("❗️App Will Resign")
            backgrounded = Date.now
#if TALER_NIGHTLY
            sheetType = nil
#else
            showScanner = false
#endif
        }   // App Will Resign
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification, object: nil)) { _ in
            logger.log("❗️App Will Enter Foreground")
            if let backgrounded {
                let interval = Date.now - backgrounded
                if interval.seconds > 10 {      // enough time to paste copied data and return
                    // TODO: add another toggle with snail/hare for 60 sec / 10 sec
                    biometricService.isAuthenticated = false
                    if useAuthentication {      // we lock now: a sheet which was open before
#if TALER_NIGHTLY
                        sheetType = nil         // must not come back after authentication
#else
                        showUrlSheet = false    // (showScanner is already off, see Resign)
                        showActionSheet = false
#endif
                    }
                }
                if interval.seconds > 30 {
                    logger.log("More than 30 seconds in background - tell wallet-core")
                    hintApplicationResumed()
                }
            }
            backgrounded = nil
        }   // App Will Enter Foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: nil)) { _ in
            logger.log("❗️App Did Become Active")
        }   // App Did Become Active
    } // body
}
// MARK: -
class NamespaceWrapper: ObservableObject {
    var namespace: Namespace.ID

    init(_ namespace: Namespace.ID) {
        self.namespace = namespace
    }
}
