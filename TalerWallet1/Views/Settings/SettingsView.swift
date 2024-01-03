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
 */

struct SettingsView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
//    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("useHaptics") var useHaptics: Bool = true
    @AppStorage("playSoundsI") var playSoundsI: Int = 1
    @AppStorage("playSoundsB") var playSoundsB: Bool = true
    @AppStorage("talerFont") var talerFont: Int = 0
    @AppStorage("developDelay") var developDelay: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("iconOnly") var iconOnly: Bool = false

#if TABBAR  // Taler Wallet
#else       // GNU Taler
    var hamburgerAction: () -> Void
#endif

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false
#if DEBUG
    @State private var diagnosticModeEnabled = true
#else
    @State private var diagnosticModeEnabled = UserDefaults.standard.bool(forKey: "diagnostic_mode_enabled")
#endif
    @State private var showDevelopItems = false
    @State private var hideDescriptions = false
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
            Task { // runs on MainActor
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
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
#if TABBAR  // Taler Wallet
        let hamburger: HamburgerButton? = nil
#else       // GNU Taler
        let hamburger: HamburgerButton = HamburgerButton(action: hamburgerAction)
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
                let aboutStr = String(localized: "About GNU Taler")
                NavigationLink {        // whole row like in a tableView
                    LazyView { AboutView(stack: stack.push(), navTitle: aboutStr) }
                } label: {
                    SettingsItem(name: aboutStr, id1: "about",
                          description: hideDescriptions ? nil : String(localized: "More info about this app...")) {}
                }
#if DEBUG
                Group {
                    Text("https://bank.taler.grothoff.org/")
                    Text("https://bank.taler.fdold.eu/")
                    Text("https://bank.head.taler.net/")
                    Text("https://bank.test.taler.net/")
                    Text("https://bank.demo.taler.net/")
                }
#endif
                if controller.hapticCapability.supportsHaptics {
                    SettingsToggle(name: String(localized: "Haptics"), value: $useHaptics, id1: "haptics",
                            description: hideDescriptions ? nil : String(localized: "Vibration Feedback"))
                    .id("playHaptics")
                }
                let playToggle = SettingsToggle(name: String(localized: "Play Payment Sounds"), value: $playSoundsB,
                                         description: hideDescriptions ? nil : String(localized: "When a transaction finished"))
                                    .id("playSounds")
#if DEBUG
                if Double.random(in: -100.0...100.0) > 0 {
                    SettingsSpeaker(name: String(localized: "Play Payment Sounds"), value: $playSoundsI,
                         description: hideDescriptions ? nil : String(localized: "When a transaction finished"))
                .id("playSounds")
                SettingsFont(title: String(localized: "Font:"), value: talerFont, action: redraw)
                    .id("font")
                } else { playToggle }
#else
                playToggle
#endif
                SettingsStyle(title: String(localized: "Liststyle:"), myListStyle: $myListStyle)
                    .id("liststyle")
                SettingsToggle(name: String(localized: "Minimalistic"), value: $iconOnly, id1: "minimal",
                        description: hideDescriptions ? nil : String(localized: "Omit text where possible")) {
                    hideDescriptions = iconOnly //withAnimation { hideDescriptions = iconOnly }
                }
                if diagnosticModeEnabled {
                    SettingsToggle(name: String("Developer Mode"), value: $developerMode, id1: "devMode",
                            description: hideDescriptions ? nil : String("More information intended for debugging")) {
                        withAnimation { showDevelopItems = developerMode }
                    }
                    if showDevelopItems {  // show or hide the following items
                        SettingsItem(name: String("Withdraw \(DEMOCURRENCY)"), id1: "demo1with",
                              description: hideDescriptions ? nil : String("Get money for testing")) {
                            let title = "Withdraw"
                            Button(title) {
                                withDrawDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("demo1withdraw")
                        SettingsItem(name: String("Withdraw \(TESTCURRENCY)"), id1: "test1with",
                              description: hideDescriptions ? nil : String("Get money for testing")) {
                            let title = "Withdraw"
                            Button(title) {
                                withDrawDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("test1withdraw")
                        SettingsToggle(name: String("Set 2 seconds delay"),
                                       value: $developDelay.onChange({ delay in
                            walletCore.developDelay = delay}), id1: "delay",
                                       description: hideDescriptions ? nil : String("After each wallet-core action"))
                            .id("delay")
                        SettingsItem(name: String("Run Integration Test"), id1: "demo1test",
                              description: hideDescriptions ? nil : String("Perform basic test transactions")) {
                            let title = "Demo 1"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("demo1runTest")
                        SettingsItem(name: String("Run Integration Test"), id1: "test1test",
                              description: hideDescriptions ? nil : "Perform basic test transactions") {
                            let title = "Test 1"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("test1runTest")
                        SettingsItem(name: String("Run Integration Test V2"), id1: "demo2test",
                              description: hideDescriptions ? nil : String("Perform more test transactions")) {
                            let title = "Demo 2"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("demo2runTest")
                        SettingsItem(name: String("Run Integration Test V2"), id1: "test2test",
                              description: hideDescriptions ? nil : String("Perform more test transactions")) {
                            let title = "Test 2"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
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
                        }.id("test2runTest")
                        SettingsItem(name: String("Save Logfile"), id1: "save",
                              description: hideDescriptions ? nil : String("Help debugging wallet-core")) {
                            Button("Save") {
                                symLog.log("Saving Log")
                                // FIXME: Save Logfile
                            }
                            .buttonStyle(.bordered)
                            .disabled(true)
                        }.id("saveLog")
                        SettingsItem(name: String("Reset Wallet"), id1: "reset",
                              description: hideDescriptions ? nil : String("Throw away all your money")) {
                            Button("Reset") {
                                showResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(didReset)
                        }.id("resetWallet")
                    }
                }
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .navigationBarItems(leading: hamburger)
        .onAppear() {
            showDevelopItems = developerMode
            hideDescriptions = iconOnly
            DebugViewC.shared.setViewID(VIEW_SETTINGS, stack: stack.push())
        }
        .onDisappear() {
            checkDisabled = false    // reset
            withDrawDisabled = false
        }
        .alert("Reset Wallet",
               isPresented: $showResetAlert,
               actions: { dismissAlertButton
                          resetButton },
               message: {   Text(verbatim: "Are you sure you want to reset your wallet?\nThis cannot be reverted, all money will be lost.") })

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
// MARK: -
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
#if TABBAR  // Taler Wallet
        SettingsView(stack: CallStack("Preview"), navTitle: "Settings")
#else       // GNU Taler
        SettingsView(stack: CallStack("Preview"), navTitle: "Settings") { }
#endif
    }
}
#endif
