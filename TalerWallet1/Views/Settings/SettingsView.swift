/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

/*
 * Backup
 * Last backup: 5 hr. ago
 *
 * Debug log
 * View/send internal log
 *
 * Reset Wallet (dangerous!)
 * Throws away your money
 */

struct SettingsView: View {
    private let symLog = SymLogV(0)
    let navTitle: String

    @EnvironmentObject private var controller: Controller
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("useHaptics") var useHaptics: Bool = false
    @AppStorage("playSounds") var playSounds: Int = 0
    @AppStorage("talerFont") var talerFont: Int = 0
    @AppStorage("developDelay") var developDelay: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var hamburgerAction: () -> Void

    @EnvironmentObject private var model: WalletModel

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false
#if DEBUG
    @State private var diagnosticModeEnabled = true
#else
    @State private var diagnosticModeEnabled = UserDefaults.standard.bool(forKey: "diagnostic_mode_enabled")
#endif
    @State private var showDevelopItems = false
    @State private var showResetAlert: Bool = false
    @State private var didReset: Bool = false

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showResetAlert = false
        }
    }
    private var resetButton: some View {
        Button("Reset", role: .destructive) {
            didReset = true
            showResetAlert = false
            Task {
                symLog.log("❗️Reset wallet-core❗️")
                do {
                    try await model.resetWalletCoreT()
                } catch {    // TODO: show error
                    symLog.log(error.localizedDescription)
                }
            }
        }
    }
    @State private var listID = UUID()

    func redraw(_ newFont: Int) -> Void {
        if newFont != talerFont {
            talerFont = newFont
            withAnimation { listID = UUID() }
        }
    }
    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
                if controller.hapticCapability.supportsHaptics {
                    SettingsToggle(name: String(localized: "Haptics"), value: $useHaptics,
                                   description: String(localized: "Vibration Feedback"))
                }
                SettingsSpeaker(name: String(localized: "Play Payment Sounds"), value: $playSounds,
                                description: String(localized: "When a transaction finished"))
                SettingsFont(title: String(localized: "Font:"), value: talerFont, action: redraw)
                SettingsStyle(title: String(localized: "Liststyle:"), myListStyle: $myListStyle)
                if diagnosticModeEnabled {
                    SettingsToggle(name: String(localized: "Developer Mode"), value: $developerMode,
                            description: String(localized: "More information intended for debugging")) {
                        DebugViewC.shared.setViewID(VIEW_SETTINGS)
                        withAnimation { showDevelopItems = developerMode }
                    }
                    if showDevelopItems {  // show or hide the following items
                        NavigationLink {        // whole row like in a tableView
                            LazyView { PendingOpsListView() }
                        } label: {
                            SettingsItem(name: String(localized: "Pending Operations"),
                                  description: String(localized: "Exchange not yet ready...")) {}
                        }
                        SettingsToggle(name: String(localized: "Set 2 seconds delay"),
                                      value: $developDelay.onChange({ delay in
                                        walletCore.developDelay = delay}),
                                description: String(localized: "After each wallet-core action"))
                        SettingsItem(name: String(localized: "Withdraw \(DEMOCURRENCY)"),
                              description: String(localized: "Get money for testing")) {
                            Button("Withdraw") {
                                withDrawDisabled = true    // don't run twice
                                Task {
                                    symLog.log("Withdraw KUDOS")
                                    do {
                                        try await model.loadTestKudosM(test: false)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(withDrawDisabled)
                        }
                        SettingsItem(name: String(localized: "Withdraw \(TESTCURRENCY)"),
                              description: String(localized: "Get money for testing")) {
                            Button("Withdraw") {
                                withDrawDisabled = true    // don't run twice
                                Task {
                                    symLog.log("Withdraw TESTKUDOS")
                                    do {
                                        try await model.loadTestKudosM(test: true)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(withDrawDisabled)
                        }
                        SettingsItem(name: String(localized: "Run Integration Test"),
                              description: String(localized: "Perform basic test transactions")) {
                            Button("Demo 1") {
                                checkDisabled = true    // don't run twice
                                Task {
                                    symLog.log("running integration test on demo")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: false, test: false)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }
                        SettingsItem(name: String(localized: "Run Integration Test"),
                              description: String(localized: "Perform basic test transactions")) {
                            Button("Test 1") {
                                checkDisabled = true    // don't run twice
                                Task {
                                    symLog.log("running integration test on test")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: false, test: true)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }
                        SettingsItem(name: String(localized: "Run Integration Test V2"),
                              description: String(localized: "Perform more test transactions")) {
                            Button("Demo 2") {
                                checkDisabled = true    // don't run twice
                                Task {
                                    symLog.log("running integration test V2 on demo")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: true, test: false)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }
                        SettingsItem(name: String(localized: "Run Integration Test V2"),
                              description: String(localized: "Perform more test transactions")) {
                            Button("Test 2") {
                                checkDisabled = true    // don't run twice
                                Task {
                                    symLog.log("running integration test V2 on test")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: true, test: true)
                                    } catch {    // TODO: show error
                                        symLog.log(error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }
                        SettingsItem(name: String(localized: "Save Logfile"),
                              description: String(localized: "Help debugging wallet-core")) {
                            Button("Save") {
                                symLog.log("Saving Log")
                                // FIXME: Save Logfile
                            }
                            .buttonStyle(.bordered)
                            .disabled(true)
                        }
                        SettingsItem(name: String(localized: "Reset Wallet"),
                              description: String(localized: "Throw away all your money")) {
                            Button("Reset") {
                                showResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(didReset)
                        }
                    }
                }

                VStack {
                    SettingsItem(name: "App Version") {
                        Text(verbatim: "\(Bundle.main.releaseVersionNumberPretty)")
                    }
                    SettingsItem(name: "Wallet Core Version") {
                        Text(verbatim: "\(walletCore.versionInfo!.version)")
                    }
                    SettingsItem(name: "Wallet Core DevMode") {
                        Text(verbatim: "\(walletCore.versionInfo!.devMode ? "YES" : "NO")")
                    }
                    SettingsItem(name: "Supported Exchange Versions") {
                        Text(verbatim: "\(walletCore.versionInfo!.exchange)")
                    }
                    SettingsItem(name: "Supported Merchant Versions") {
                        Text(verbatim: "\(walletCore.versionInfo!.merchant)")
                    }
                    SettingsItem(name: "Used Bank") {
                        Text(verbatim: "\(walletCore.versionInfo!.bank)")
                    }
                } // App version info
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .navigationBarItems(leading: HamburgerButton(action: hamburgerAction))
        .onAppear() {
            showDevelopItems = developerMode
            DebugViewC.shared.setViewID(VIEW_SETTINGS)
        }
        .alert("Reset Wallet",
               isPresented: $showResetAlert,
               actions: { dismissAlertButton
                          resetButton },
               message: {   Text("Are you sure you want to reset your wallet?\nThis cannot be reverted, all money will be lost.") })

#if !DEBUG
        .onReceive(
            NotificationCenter.default
                .publisher(for: UserDefaults.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in            // user changed Diagnostic Mode in iOS Settings.app
            withAnimation { diagnosticModeEnabled = UserDefaults.standard.bool(forKey: "diagnostic_mode_enabled") }
        }
#endif
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
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(navTitle: "Settings") { }
    }
}
#endif
