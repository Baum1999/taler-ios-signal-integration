/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct AboutView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var controller: Controller
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var rotationEnabled = false

    @State private var listID = UUID()

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
//                VStack {
                    HStack {
                        Spacer()
                        RotatingTaler(size: 100, rotationEnabled: $rotationEnabled)
                            .accessibilityHint("will go to the taler.net website when long-pressed")
                            .onTapGesture(count: 2) {
                                rotationEnabled.toggle()
                            }
                            .onLongPressGesture(minimumDuration: 0.3) {
                                UIApplication.shared.open(URL(string:"https://taler.net")!, options: [:])
                            }
                        Spacer()
                    }
                    SettingsItem(name: "App Version", id1: "app") {
                        Text(verbatim: "\(Bundle.main.releaseVersionNumberPretty)")
                    }
                    SettingsItem(name: "Wallet Core Version", id1: "wallet-core") {
                        Text(verbatim: "\(walletCore.versionInfo!.version)")
                    }
                    SettingsItem(name: "Wallet Core DevMode", id1: "devMode") {
                        Text(verbatim: "\(walletCore.versionInfo!.devMode ? "YES" : "NO")")
                    }
                    SettingsItem(name: "Supported Exchange Versions", id1: "exchange") {
                        Text(verbatim: "\(walletCore.versionInfo!.exchange)")
                    }
                    SettingsItem(name: "Supported Merchant Versions", id1: "merchant") {
                        Text(verbatim: "\(walletCore.versionInfo!.merchant)")
                    }
                    SettingsItem(name: "Used Bank", id1: "bank") {
                        Text(verbatim: "\(walletCore.versionInfo!.bank)")
                    }
//                } // App version info
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_ABOUT, stack: stack.push())
        }
        .onDisappear() {
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(5))
            rotationEnabled.toggle()
        }
    }
}
extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var releaseVersionNumberPretty: String {
        return "v\(releaseVersionNumber ?? "1.0.0")"
    }
}
// MARK: -
#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
#if TABBAR  // Taler Wallet
        AboutView(stack: CallStack("Preview"), navTitle: "About")
#else       // GNU Taler
        SettingsView(stack: CallStack("Preview"), navTitle: "About") { }
#endif
    }
}
#endif
