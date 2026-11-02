/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Main app entry point
 *
 * @author Jonathan Buchanan
 * @author Marc Stibane
 */
import BackgroundTasks
import SwiftUI
import os.log
import SymLog

@main
struct TalerWallet1App: App {
#if TALER_NIGHTLY
    // we need an AppDelegate for APNs
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    private let symLog = SymLogV(-1, Bundle.main.bundleName)
    @Environment(\.scenePhase) private var phase
    @AppStorage("pasteAutomatically") var pasteAutomatically: Bool = false
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @StateObject private var viewState = ViewState.shared           // popToRootView()
    @StateObject private var viewState2 = ViewState2.shared         // popToRootView()
    @State private var pastedString: String? = nil
    @State private var pastedWebURL: String? = nil      // TODO: debounce
    @State private var stack = CallStack("App")

    private let walletCore = WalletCore.shared
    private let controller = Controller.shared
    private let model = WalletModel.shared
    private let debugViewC = DebugViewC.shared
    let logger = Logger(subsystem: "net.taler.gnu", category: "Main App")
    private let biometricService = BiometricService.shared

#if TALER_NIGHTLY
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.taler.refresh")
        request.earliestBeginDate = .now.addingTimeInterval(4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
#endif

    @MainActor
    func post(_ pastedURL: URL) {
        Task {
            let pasteType = PasteType(pastedURL: pastedURL)
            let userinfo = [NOTIFICATIONPASTE: pasteType]
            NotificationCenter.default.post(name: .PasteAction, object: nil, userInfo: userinfo)
        }
    }

    /// Opens the first taler:// URI found in `string` and keeps the others
    /// (e.g. the shares of a group split) in the list of scanned URLs.
    /// Returns false if `string` contains no taler:// URI.
    @discardableResult
    func handlePasted(_ string: String) -> Bool {
        let uris = TalerURIExtractor.extractAll(string)
        guard let first = uris.first else { return false }
#if TALER_SIGNAL
        // Mehrere Anteile (z. B. Gruppen-Split aus Signal): erst die
        // Sammelkarte, der Nutzer wählt den Anteil (MultiUriSummaryView).
        if uris.count > 1 {
            Task { @MainActor in
                NotificationCenter.default.post(name: .PasteMultiAction, object: nil,
                                                userInfo: [NOTIFICATIONPASTEMULTI: uris])
            }
            return true
        }
#endif
        Task { @MainActor in
            for uri in uris.dropFirst() {
                controller.saveURL(uri, urlCommand: controller.command(uri.host ?? EMPTYSTRING))
            }
            post(first)
        }
        return true
    }

    func inspectPasteboard(playSound: Bool) {
        let pasteboard = UIPasteboard.general
        // taler:// URIs mostly arrive as plain text, often with text around them
        if !pasteboard.hasURLs && !pasteboard.hasStrings { return }

        if playSound {
            // The user tapped Paste: read the text directly. probableWebURL
            // misses taler:// in plain text, and iOS asks before pasting anyway.
            if let string = pasteboard.string, handlePasted(string) {
                return
            }
            controller.playSound(0)     // tell the user we didn't find anything
            return
        }

        // users get asked whether they want to paste, and only if they agree we go to completion
        pasteboard.detectPatterns(for: [UIPasteboard.DetectionPattern.probableWebURL],
                            inItemSet: nil,
                    completionHandler: { result in
            switch result {
                case .success(let detectedPatterns):
                    // A pattern detection is completed,
                    // regardless of whether the pasteboard has patterns we care about.
                    // So we have to check if the detected patterns contains our patterns.

                    if detectedPatterns.contains([UIPasteboard.DetectionPattern.probableWebURL]) {
                        // Will match if the pasteboard string has a URL within it
                        self.pastedWebURL = pasteboard.string
                        if let string = pasteboard.string {
                            if self.pastedString != string {
                                self.pastedString = string
                                if handlePasted(string) {
                                    return
                                }
                            }
                        }
                    } else {
                        // We won't be retrieving the value, so we won't get a notification banner
                        self.pastedWebURL = nil
                        if playSound {
                            controller.playSound(0)     // tell the user we didn't find anything
                        }
                    }
                case .failure(let error):
                    // This never gets called
                    self.pastedWebURL = error.localizedDescription
            }
        })
    }

    var body: some Scene {
        let colorScheme = preferredColorScheme > 1 ? ColorScheme.dark
                        : preferredColorScheme > 0 ? ColorScheme.light
                                                   : nil    // use the current scheme
        let mainView = MainView(logger: logger, stack: stack.push())
                .preferredColorScheme(colorScheme)
                .environmentObject(debugViewC)      // change viewID / sheetID
                .environmentObject(viewState)       // popToRoot
                .environmentObject(viewState2)      // popToRoot
                .environmentObject(controller)
                .environmentObject(model)
                .environmentObject(biometricService)
                .environment(\.fromSheet, false)
                .addKeyboardVisibilityToEnvironment()
                    /// external events are taler:// (or in the future payto://) URLs passed to this app
                    /// we handle them in .onOpenURL in MainView.swift
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .task {
#if DEBUG
                    let testing = true
                    let delay: TimeInterval = 1.001
#else
                    let testing = false
                    let delay: TimeInterval = 2.25
#endif
                    try? await controller.initWalletCore(stack: stack.push("mainView.task"),
                                                    setTesting: testing,
                                                         delay: delay)
                }
        if #available(iOS 16.4, *) {
            return WindowGroup {
                mainView
            }
            .onChange(of: phase) { newPhase in
                switch newPhase {
                    case .active:
                        logger.log("❗️.onChange() ==> Active")
                        if pasteAutomatically {
                            inspectPasteboard(playSound: false)
                        }
                    case .background:
                        logger.log("❗️.onChange() ==> Background)")
#if TALER_NIGHTLY
//                      scheduleAppRefresh()
#endif
                    default: break
                }
            }
#if TALER_NIGHTLY
            .backgroundTask(.appRefresh("net.taler.refresh")) {
                await symLog.log("backgroundTask running")
            }
#endif
        } else {
            // Fallback on earlier versions
            return WindowGroup {
                mainView
            }
        }
    }
}
// MARK: -
struct PasteType: Hashable {
    let pastedURL: URL
}

final class ViewState : ObservableObject {
    static let shared = ViewState()
    @Published var rootViewId = UUID()
    let logger = Logger(subsystem: "net.taler.gnu", category: "ViewState")

    public func popToRootView(_ stack: CallStack?) -> Void {
        logger.info("popToRootView")
        rootViewId = UUID() // setting a new ID will cause 1st NavStack popToRootView behaviour
    }

    private init() { }
}

final class ViewState2 : ObservableObject {
    static let shared = ViewState2()
    @Published var rootViewId = UUID()
    let logger = Logger(subsystem: "net.taler.gnu", category: "ViewState2")

    public func popToRootView(_ stack: CallStack?) -> Void {
        logger.info("popToRootView")
        rootViewId = UUID() // setting a new ID will cause 2nd NavStack popToRootView behaviour
    }

    private init() { }
}
