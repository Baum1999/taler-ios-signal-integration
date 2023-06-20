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

    @AppStorage("developerMode") var developerMode: Bool = false
    @AppStorage("developDelay") var developDelay: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    var hamburgerAction: () -> Void

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false
#if DEBUG
    @State private var diagnosticModeEnabled = true
#else
    @State private var diagnosticModeEnabled = UserDefaults.standard.bool(forKey: "diagnostic_mode_enabled")
#endif
    @State private var showDevelopItems = false

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
                HStack {
                    Text("Liststyle:")
                        .font(.title2)
                    Spacer()
                    Picker(selection: $myListStyle) {
                        ForEach(MyListStyle.allCases, id: \.self) {
                            Text($0.displayName.capitalized).tag($0)
                                .font(.title2)
                        }
                    } label: {}
                        .pickerStyle(.menu)
//                        .frame(alignment: .trailing)
//                        .background(WalletColors().buttonBackColor(pressed: false, disabled: false))  TODO: RoundRect
                }
                if diagnosticModeEnabled {
                    SettingsToggle(name: String(localized: "Developer Mode"), value: $developerMode,
                                   description: String(localized: "More information intended for debugging")) {
                        DebugViewC.shared.setViewID(VIEW_SETTINGS)
                        withAnimation { showDevelopItems = developerMode }
                    }
                    if showDevelopItems {  // show or hide the following items
                        NavigationLink {        // whole row like in a tableView
                            LazyView { PendingOpsListView(model: PendingModel.model()) }
                        } label: {
                            SettingsItem(name: String(localized: "Pending Operations"), description: String(localized: "Exchange not yet ready...")) {}
                        }
                        SettingsToggle(name: String(localized: "Set 2 seconds delay"), value: $developDelay,
                                       description: String(localized: "After each wallet-core action"))
                        .onChange(of: developDelay, perform: { developDelay in
                            walletCore.developDelay = developDelay
                        })

                        SettingsItem(name: String(localized: "Withdraw \(DEMOCURRENCY)"), description: String(localized: "Get money for testing")) {
                            Button("Withdraw") {
                                withDrawDisabled = true    // don't run twice
                                Task {
                                    let model: SettingsModel = SettingsModel()
                                    symLog.log("Withdraw TestKUDOS")
                                    do {
                                        try await model.loadTestKudosM()
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
                            Button("Test 1") {
                                checkDisabled = true    // don't run twice
                                Task {
                                    let model: SettingsModel = SettingsModel()
                                    symLog.log("running integration test")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: false)
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
                                    let model: SettingsModel = SettingsModel()
                                    symLog.log("running integration test V2")
                                    do {
                                        try await model.runIntegrationTestM(newVersion: true)
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
                    }
                }

                VStack {
                    SettingsItem(name: String(localized: "App Version")) {
                        Text("\(Bundle.main.releaseVersionNumberPretty)")
                    }
                    SettingsItem(name: String(localized: "Wallet Core Version")) {
                        Text("\(walletCore.versionInfo!.version)")
                    }
                    SettingsItem(name: String(localized: "Wallet Core DevMode")) {
                        Text("\(walletCore.versionInfo!.devMode ? "YES" : "NO")")
                    }
                    SettingsItem(name: String(localized: "Supported Exchange Versions")) {
                        Text("\(walletCore.versionInfo!.exchange)")
                    }
                    SettingsItem(name: String(localized: "Supported Merchant Versions")) {
                        Text("\(walletCore.versionInfo!.merchant)")
                    }
                    SettingsItem(name: String(localized: "Used Bank")) {
                        Text("\(walletCore.versionInfo!.bank)")
                    }
                }
            }
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .navigationBarItems(leading: HamburgerButton(action: hamburgerAction))
        .onAppear() {
            showDevelopItems = developerMode
            DebugViewC.shared.setViewID(VIEW_SETTINGS)
        }
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
