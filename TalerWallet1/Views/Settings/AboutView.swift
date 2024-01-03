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
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State private var rotationEnabled = false
    @State private var listID = UUID()

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
                HStack {
                    Spacer()
                    RotatingTaler(size: 100, rotationEnabled: $rotationEnabled)
                        .onTapGesture(count: 2) {
                            rotationEnabled.toggle()
                        }
                    Spacer()
                }
                SettingsItem(name: "Visit the taler.net website", id1: "web",
                             description: iconOnly ? nil : String(localized: "More info about Gnu Taler in general...")) { }
                    .accessibilityAddTraits(.isLink)
                    .accessibilityRemoveTraits(.isStaticText)
                    .onTapGesture() {
                        UIApplication.shared.open(URL(string:TALER_NET)!, options: [:])
                    }

                SettingsItem(name: "App Version", id1: "app") {
                    Text(verbatim: "\(Bundle.main.releaseVersionNumberPretty)")
                }
                SettingsItem(name: "Wallet Core Version", id1: "wallet-core") {
                    Text(verbatim: "\(walletCore.versionInfo?.version ?? "unknown")")
                }
//                SettingsItem(name: "Supported Exchange Versions", id1: "exchange") {
//                    Text(verbatim: "\(walletCore.versionInfo?.exchange ?? "unknown")")
//                }
//                SettingsItem(name: "Supported Merchant Versions", id1: "merchant") {
//                    Text(verbatim: "\(walletCore.versionInfo?.merchant ?? "unknown")")
//                }
//                SettingsItem(name: "Used Bank", id1: "bank") {
//                    Text(verbatim: "\(walletCore.versionInfo?.bank ?? "unknown")")
//                }
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
        AboutView(stack: CallStack("Preview"), navTitle: "About")
    }
}
#endif
