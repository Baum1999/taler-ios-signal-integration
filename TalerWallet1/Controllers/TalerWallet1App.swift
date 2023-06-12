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
import SymLog

@main
struct TalerWallet1App: App {
    private let symLog = SymLogV()
    @Environment(\.scenePhase) private var phase
    @StateObject private var viewState = ViewState.shared         // popToRootView()
    @State private var isActive = true

    private let walletCore = WalletCore.shared
    // our main controller
    private let controller = Controller.shared
    private let debugViewC = DebugViewC.shared

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.taler.refresh")
        request.earliestBeginDate = .now.addingTimeInterval(24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(debugViewC)      // change viewID / sheetID
                .environmentObject(viewState)       // popToRoot
                .environmentObject(controller)
                    /// external events are taler:// or payto:// URLs passed to this app
                    /// we handle them in .onOpenURL in MainView.swift
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .task {
                    symLog.log("task -> initWalletCore")
                    try! await controller.initWalletCoreM()      // will (and should) crash on failure
                    symLog.log("task -> initWalletCore done")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: nil)) { _ in
                    print("❗️App Did Become Active notification")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification, object: nil)) { _ in
                    print("❗️App Will Resign notification")
                    isActive = false
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification, object: nil)) { _ in
                    print("❗️App Will Enter Foreground notification")
                    isActive = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification, object: nil)) { _ in
                    print("❗️App Will Terminate notification")
                }

        }
        .onChange(of: phase) { newPhase in
            switch newPhase {
                case .active:
                    print("❗️ .onChange(of: phase) ==> newPhase: Active")
                case .background:
                    print("❗️ .onChange(of: phase) ==> newPhase: Background)")
                    scheduleAppRefresh()
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

    public func popToRootView() -> Void {
        let _ = symLog()
        rootViewId = UUID() // setting a new ID will cause tableView popToRootView behaviour
    }

    private init() { }
}
