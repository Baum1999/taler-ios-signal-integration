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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    private let symLog = SymLogV()
    @Environment(\.scenePhase) private var phase
    @StateObject private var viewState = ViewState.shared           // popToRootView()
    @StateObject private var viewState2 = ViewState2.shared         // popToRootView()
    @State private var soundPlayed = false

    private let walletCore = WalletCore.shared
    private let controller = Controller.shared
    private let model = WalletModel.shared
    private let debugViewC = DebugViewC.shared
    let logger = Logger(subsystem: "net.taler.gnu", category: "Main App")
    private let biometricService = BiometricService.shared

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.taler.refresh")
        request.earliestBeginDate = .now.addingTimeInterval(4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        let mainView = MainView(logger: logger, stack: CallStack("App"), soundPlayed: $soundPlayed)
                .environmentObject(debugViewC)      // change viewID / sheetID
                .environmentObject(viewState)       // popToRoot
                .environmentObject(viewState2)      // popToRoot
                .environmentObject(controller)
                .environmentObject(model)
                .environmentObject(biometricService)
                .addKeyboardVisibilityToEnvironment()
                    /// external events are taler:// or payto:// URLs passed to this app
                    /// we handle them in .onOpenURL in MainView.swift
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .task {
#if DEBUG
                    let testing = true
                    let delay: TimeInterval = 2.25
#else
                    let testing = false
                    let delay: TimeInterval = 0.05      // TODO: also 2.25?
#endif
                    try! await controller.initWalletCore(model, setTesting: testing, delay: delay)     // will (and should) crash on failure
                }
        if #available(iOS 16.4, *) {
            return WindowGroup {
                mainView
            }
            .onChange(of: phase) { newPhase in
                switch newPhase {
                    case .active:
                        logger.log("❗️.onChange() ==> Active")
                    case .background:
                        logger.log("❗️.onChange() ==> Background)")
//                      scheduleAppRefresh()
                    default: break
                }
            }
            .backgroundTask(.appRefresh("net.taler.refresh")) {
//                symLog.log("backgroundTask running")
//#if 0
//                let request = URLRequest(url: URL(string: "your_backend")!)
//                guard let data = try? await URLSession.shared.data(for: request).0 else {
//                    return
//                }
//                
//                let decoder = JSONDecoder()
//                guard let products = try? decoder.decode([Product].self, from: data) else {
//                    return
//                }
//                
//                if !products.isEmpty && !Task.isCancelled {
//                    await notifyUser(for: products)
//                }
//#endif
            }
        } else {
            // Fallback on earlier versions
            return WindowGroup {
                mainView
            }
        }

    }
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
