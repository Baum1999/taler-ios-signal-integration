/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import BackgroundTasks
import SwiftUI
import SymLog
#if DEBUG
let schemes: Set = ["taler", "payto", "taler+http"]
#else
let schemes: Set = ["taler", "payto"]
#endif

@main
struct TalerWallet1App: App {
    private let symLog = SymLogV(0)
    @Environment(\.scenePhase) private var phase

    // our main controller
    @StateObject private var controller = Controller.shared

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.taler.refresh")
        request.earliestBeginDate = .now.addingTimeInterval(24 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            symLog { ContentView()
                    .environmentObject(controller)
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                    .task {
                        symLog.log("task -> initWalletCore")
                        try! await controller.initWalletCore()      // will (and should) crash on failure
                        symLog.log("task done")
                    }
            }
        }
        .onChange(of: phase) { newPhase in
            switch newPhase {
                case .background: scheduleAppRefresh()
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
