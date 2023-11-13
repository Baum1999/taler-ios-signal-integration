/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Main app entry point
 *
 * @author Marc Stibane
 * @author Jonathan Buchanan
 */
import BackgroundTasks
import SwiftUI
import os.log
import SymLog

@main
struct TalerWallet1App: App {
    private let symLog = SymLogV()
    @Environment(\.scenePhase) private var phase
    @StateObject private var viewState = ViewState.shared         // popToRootView()
    @State private var isActive = true
    @State private var soundPlayed = false

    private let walletCore = WalletCore.shared
    private let controller = Controller.shared
    private let model = WalletModel.shared
    private let debugViewC = DebugViewC.shared
    let logger = Logger(subsystem: "net.taler.gnu", category: "Main App")
    let sqlite3 = true                                                          // true = SQLITE3, false = JSON

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.taler.gnu.refresh")
        request.earliestBeginDate = .now.addingTimeInterval(24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            MainView(logger: logger, stack: CallStack("App"), soundPlayed: $soundPlayed)
                .environmentObject(debugViewC)      // change viewID / sheetID
                .environmentObject(viewState)       // popToRoot
                .environmentObject(controller)
                .environmentObject(model)
                    /// external events are taler:// or payto:// URLs passed to this app
                    /// we handle them in .onOpenURL in MainView.swift
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .task {
                    try! await controller.initWalletCore(model, sqlite3: sqlite3)     // will (and should) crash on failure
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: nil)) { _ in
                    logger.log("❗️App Did Become Active")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification, object: nil)) { _ in
                    logger.log("❗️App Will Resign")
                    isActive = false
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification, object: nil)) { _ in
                    logger.log("❗️App Will Enter Foreground")
                    isActive = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification, object: nil)) { _ in
                    logger.log("❗️App Will Terminate")
                }

        }
        .onChange(of: phase) { newPhase in
            switch newPhase {
                case .active:
                    logger.log("❗️.onChange() ==> Active")
                case .background:
                    logger.log("❗️.onChange() ==> Background)")
//                    scheduleAppRefresh()
                default: break
            }
        }
//        if #available(iOS 16.0, *) {
//            .backgroundTask(.appRefresh("net.taler.refresh")) {
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
//            }
//        } else {
//            // Fallback on earlier versions
//        }

    }
}

final class ViewState : ObservableObject {
    static let shared = ViewState()
    @Published var rootViewId = UUID()
    let logger = Logger(subsystem: "net.taler.gnu", category: "ViewState")

    public func popToRootView() -> Void {
        logger.info("popToRootView")
        rootViewId = UUID() // setting a new ID will cause tableView popToRootView behaviour
    }

    private init() { }
}
