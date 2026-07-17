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
    @State private var selectedBalance: Balance? = nil      // for sheets, gets set in TransactionsListView
    @State private var urlToOpen: URL? = nil
    @State private var sheetType: SheetType?
    @State private var showUrlSheet = false
    @State private var showActionSheet = false              // Action button tapped
    @State private var showScanner = false
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
    }

    private func dismissSheet() {
        logger.info("dismissSheet")
        showScanner = false
        showActionSheet = false
        scannedCode = false
        controller.userAction += 1                      // make Action button jump
        // TODO: wallet-core could notify us when it creates a dialog tx
        NotificationCenter.default.post(name: .TransactionScanned, object: nil, userInfo: nil)
    }

    private func dismissActionSheet() {
        logger.info("dismissActionSheet")
        showActionSheet = false
        controller.userAction += 1                      // make Action button jump
    }

    func hintApplicationResumed() {
        Task.detached {
            await model.hintApplicationResumedT()
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

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let mainContent = ZStack {
            WalletMain(logger: logger, stack: stack.push("Content"),
              selectedBalance: $selectedBalance,
               talerFontIndex: $talerFontIndex,
              showActionSheet: $showActionSheet,
                  showScanner: $showScanner)
            .environmentObject(NamespaceWrapper(namespace))
            .overlay(alignment: .top) {
                DebugViewV()
            }     // Show the viewID on top of the app's NavigationView

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
            }   // biometrics

        let mainGroup = Group {
            // show launch animation until either ready or error
            switch controller.backendState {
                case .ready: mainContent
                case .error(let error): ErrorView(stack.push("mainGroup"),
                                                  title: EMPTYSTRING,   // TODO: String(localized: ""),
                                               copyable: true) {}
                default:     LaunchAnimationView()
            }
        }.animation(.linear(duration: LAUNCHDURATION), value: controller.backendState)

        VStack {
            if controller.networkUnavailable {
                ErrorBanner(.networkUnavailable)        // red bar on top
            } else if controller.slowConnection {
                ErrorBanner(.warning5sec)               // yellow bar on top
            }
            mainGroup
                .environmentObject(tabBarModel)
//              .animation(.default, value: model.error2 == nil)
                .sheet(item: $sheetType,
                  onDismiss: sheetDismissed) { sheet in
                    switch sheet {
                        case .action:
                            actionSheet()
                        case .scanner:
                            qrSheet()
                                .environmentObject(tabBarModel)
                        case .url(let url):
                            let uSheet = URLSheet(stack.push(),
                                        selectedBalance: selectedBalance,
                                               sheetURL: url)
                                .id("onOpenURL")
                            Sheet(stack: stack.push(), sheetView: AnyView(uSheet))
                                .environmentObject(tabBarModel)
                    }
                }
                .sheet(isPresented: $showUrlSheet,
                         onDismiss: sheetDismissed) {
                    let sheet = URLSheet(stack.push(),
                               selectedBalance: selectedBalance,
                                     urlToOpen: $urlToOpen)
                        .id("onOpenURL")
                    Sheet(stack: stack.push(), sheetView: AnyView(sheet))
                        .environmentObject(tabBarModel)
                }   // UrlSheet
                .sheet(isPresented: $showScanner,
                         onDismiss: dismissSheet) {
                    qrSheet()
                        .environmentObject(tabBarModel)
                }   // QR Scanner
                .sheet(isPresented: $showActionSheet,
                         onDismiss: dismissActionSheet
                ) {
                    actionSheet()
                        .environmentObject(tabBarModel)
                }   // ActionSheet
        }   // VStack { networkUnavailable + mainGroup }
#if OIM
        // set controller.oimModeActive
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
        .onNotification(.QrScanAction) {
            let delay = if #available(iOS 16.4, *) { 0.3 } else { 0.01 }
            logger.info("QrScanAction notification: showScanner = true")
            withAnimation(Animation.easeOut(duration: 0.5).delay(delay)) {
                showActionSheet = false
                showScanner = true      // switch to qrSheet => camera on
        }   }

        .onNotification(.PasteAction) { notification in
            if let notifData = notification.userInfo?[NOTIFICATIONPASTE] as? PasteType {
                symLog.log(".PasteAction: \(notifData)")
                urlToOpen = notifData.pastedURL
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showUrlSheet = true     // raise sheet
        }   }   }

        .onOpenURL { url in
            symLog.log(".onOpenURL: \(url)")
            // will be called on a taler:// scheme either
            // by user tapping such link in a browser (bank website)
            // or when launching the app from iOS Camera.app scanning a QR code
            urlToOpen = url
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showUrlSheet = true     // raise sheet
        }   }

        .onChange(of: controller.talerURI) { url in
            if url != nil {
                urlToOpen = url
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    controller.talerURI = nil
                    showUrlSheet = true     // raise sheet
        }   }   }

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
                            controller.slowConnection = false
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
            showScanner = false
        }   // App Will Resign
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
