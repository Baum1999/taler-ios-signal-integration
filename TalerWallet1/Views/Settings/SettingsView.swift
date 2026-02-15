/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog
import LocalConsole

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
    @EnvironmentObject private var biometricService: BiometricService
//    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("logTransactions") var logTransactions: Bool = false
    @AppStorage("useHaptics") var useHaptics: Bool = true
    @AppStorage("playSoundsI") var playSoundsI: Int = 1
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
//    @AppStorage("increaseContrast") var increaseContrast: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
    @AppStorage("developDelay") var developDelay: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("localConsoleL") var localConsoleL: Bool = false                // for Logs
    @AppStorage("localConsoleO") var localConsoleO: Int = 0                     // for Observability
    @AppStorage("useAuthentication") var useAuthentication: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true
    @AppStorage("showQRauto17") var showQRauto17: Bool = false
    @AppStorage("oimEuro") var oimEuro: Bool = false
    @AppStorage("oimChart") var oimChart: Bool = false

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false
#if DEBUG
    @State private var diagnosticModeEnabled = true
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
        Button("Reset", role: .destructive) {                                   // TODO: WalletColors().errorColor
            didReset = true
            showResetAlert = false
            Task { // runs on MainActor
                symLog.log("❗️Reset wallet-core❗️")
                try? await model.resetWalletCore()
            }
        }
    }
    @State private var listID = UUID()

    func redraw(_ newFont: Int) -> Void {
        if newFont != talerFontIndex {
            talerFontIndex = newFont
            withAnimation { listID = UUID() }
        }
    }
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        Group {
            List {
#if DEBUG
                if showDevelopItems {
                    SettingsToggle(name: String("Log Transactions"), value: $logTransactions.onChange({ isLogging in
                        walletCore.logTransactions = isLogging}), id1: "logTransactions",
                            description: hideDescriptions ? nil : String("full log with all tx")) {}
                }
#endif
#if TALER_WALLET
                let appName = "Taler Wallet"
#elseif TALER_NIGHTLY
                let appName = "Taler Nightly"
#else
                let appName = "GNU Taler"
#endif
                let localizedAppName = Bundle.main.bundleName ?? appName
                let aboutStr = String(localized: "About \(localizedAppName)")
                NavigationLink {        // whole row like in a tableView
                    AboutView(stack: stack.push(), navTitle: aboutStr)
                } label: {
                    SettingsItem(name: aboutStr, id1: "about",
                          description: hideDescriptions ? nil : String(localized: "More info about this app...")) {}
                }

                let exchangesTitle = String(localized: "TitleExchanges", defaultValue: "Payment Services")
                let exchangesDest = ExchangeListView(stack: stack.push(exchangesTitle),
                                                  navTitle: exchangesTitle,
                                          showDevelopItems: showDevelopItems)
                NavigationLink {        // whole row like in a tableView
                    exchangesDest
                } label: {
                    SettingsItem(name: exchangesTitle, id1: "exchanges",
                          description: hideDescriptions ? nil : String(localized: "Manage payment services...")) {}
                }
                let bankAccountsTitle = String(localized: "TitleBankAccounts", defaultValue: "Bank Accounts")
                let bankAccountsDest = BankListView(stack: stack.push(bankAccountsTitle),
                                                 navTitle: bankAccountsTitle)
                NavigationLink {        // whole row like in a tableView
                    bankAccountsDest
                } label: {
                    SettingsItem(name: bankAccountsTitle, id1: "bankAccounts",
                                 description: hideDescriptions ? nil : String(localized: "Your accounts for deposit...")) {}
                }
                let showQRstring = String(localized: "Show QR codes")
                let showQRhint = String(localized: "Automatically for P2P transactions")
                if #available(iOS 17.7, *) {
                    SettingsToggle(name: showQRstring, value: $showQRauto17, id1: "showQRautomatic",
                            description: minimalistic ? nil : showQRhint) {}
                } else {
                    SettingsToggle(name: showQRstring, value: $showQRauto16, id1: "showQRautomatic",
                            description: minimalistic ? nil : showQRhint) {}
                }
                SettingsToggle(name: String(localized: "Use FaceID / TouchID"), value: $useAuthentication, id1: "useFaceID",
                        description: minimalistic ? nil : String(localized: "Protect your money")) {
                    biometricService.isAuthenticated = false
                }

                /// Backup
                let backupTitle = String(localized: "TitleBackup", defaultValue: "Backup / Restore")
                let backupDest = BackupView(stack: stack.push(backupTitle),
                                         navTitle: backupTitle)
                NavigationLink {        // whole row like in a tableView
                    backupDest
                } label: {
                    SettingsItem(name: backupTitle, id1: "backup",
                          description: hideDescriptions ? nil : String(localized: "Backup your money...")) {}
                }

                /// Report
                let reportTitle = String(localized: "TitleReport", defaultValue: "Report diagnostics")
                let reportDest = ReportView(stack: stack.push(reportTitle),
                                         navTitle: reportTitle)
                NavigationLink {        // whole row like in a tableView
                    reportDest
                } label: {
                    SettingsItem(name: reportTitle, id1: "report",
                          description: hideDescriptions ? nil : String(localized: "Help improve this app...")) {}
                }

#if OIM
                SettingsToggle(name: String(localized: "OIM: Euro"), value: $oimEuro, id1: "oimEuro",
                        description: minimalistic ? nil : String(localized: "OIM currency for KUDOS"))
#endif
#if OIM
                SettingsToggle(name: String(localized: "OIM: Chart"), value: $oimChart, id1: "oimChart",
                        description: minimalistic ? nil : String(localized: "OIM history as chart"))
#endif

                SettingsToggle(name: String(localized: "Minimalistic"), value: $minimalistic, id1: "minimal",
                        description: hideDescriptions ? nil : String(localized: "Omit text where possible")) {
                    hideDescriptions = minimalistic //withAnimation { hideDescriptions = minimalistic }
                }
                if controller.hapticCapability.supportsHaptics {
                    SettingsToggle(name: String(localized: "Haptics"), value: $useHaptics, id1: "haptics",
                            description: hideDescriptions ? nil : String(localized: "Vibration Feedback"))
                }
                SettingsToggle(name: String(localized: "Play Payment Sounds"), value: $playSoundsB, id1: "playSounds",
                        description: hideDescriptions ? nil : String(localized: "When a transaction finished"))
                SettingsToggle(name: String(localized: "Show Warnings"), value: $shouldShowWarning, id1: "warnings",
                        description: hideDescriptions ? nil : String(localized: "For Delete, Abandon & Abort buttons"))
//                SettingsFont(title: String(localized: "Font:"), value: talerFontIndex, action: redraw)
//                    .id("font")
                SettingsStyle(title: String(localized: "List Style:"), myListStyle: $myListStyle)
                    .id("liststyle")
#if DEBUG
                let showDiagnostic = diagnosticModeEnabled
#else
                let showDiagnostic = controller.diagnosticModeEnabled
#endif
                if showDiagnostic {
                    let localConsStr = String("on LocalConsole")
                    let observability = String("Observe walletCore")
                    SettingsTriState(name: observability, value: $localConsoleO.onChange({ isObserving in
                        walletCore.isObserving = isObserving}),
                              description: hideDescriptions ? nil : localConsStr) { isObserving in
                        let consoleManager = LCManager.shared
                        consoleManager.isVisible = localConsoleO != 0 || localConsoleL
                        consoleManager.clear()
                    }
                    let showLogs = String("Show logs")
                    SettingsToggle(name: showLogs, value: $localConsoleL.onChange({ isLogging in
                        walletCore.isLogging = isLogging}), id1: "localConsoleL",
                            description: hideDescriptions ? nil : localConsStr) {
                        let consoleManager = LCManager.shared
                        consoleManager.isVisible = localConsoleO != 0 || localConsoleL
                        consoleManager.clear()
                    }
                    SettingsToggle(name: String("Developer Mode"), value: $developerMode, id1: "devMode",
                            description: hideDescriptions ? nil : String("More information intended for debugging")) {
                        withAnimation(Animation.linear.delay(0.8)) { showDevelopItems = developerMode }
                    }
#if DEBUG
                    if showDevelopItems {
                        let banks = ["glstest.taler.net", "taler.fdold.eu", "regio-taler.fdold.eu",
                                     "taler.grothoff.org", "taler.ar",
                                     "head.taler.net", "test.taler.net", "demo.taler.net", "kyctest.taler.net"]
                        ForEach(banks, id: \.self) { bank in
                            let urlStr = "https://bank." + bank
                            Link(bank, destination: URL(string: urlStr)!)
                        }
                    }
#endif
                    if showDevelopItems {  // show or hide the following items
                        SettingsItem(name: String("DEMO"), id1: "demo1with",
                              description: hideDescriptions ? nil : String("Get money for testing")) {
                            let title = "Withdraw"
                            Button(title) {
                                withDrawDisabled = true    // don't run twice
                                Task { // runs on MainActor
                                    symLog.log("Withdraw DEMO KUDOS")
                                    let amount = Amount(currency:  DEMOCURRENCY, cent: 11100)
                                    try? await model.loadTestKudos(0, amount: amount)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(withDrawDisabled)
                        }.id("demo1withdraw")
                        SettingsItem(name: String("TEST"), id1: "test1with",
                              description: hideDescriptions ? nil : String("Get money for testing")) {
                            let title = "Withdraw"
                            Button(title) {
                                withDrawDisabled = true    // don't run twice
                                Task { // runs on MainActor
                                    symLog.log("Withdraw TESTKUDOS")
                                    let cent = UInt64.random(in: 110...195) * 100
                                    let amount = Amount(currency:  TESTCURRENCY, cent: cent)
                                    try? await model.loadTestKudos(1, amount: amount)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(withDrawDisabled)
                        }.id("test1withdraw")
                        SettingsItem(name: String("HEAD"), id1: "head1with",
                              description: hideDescriptions ? nil : String("Get money for testing")) {
                            let title = "Withdraw"
                            Button(title) {
                                withDrawDisabled = true    // don't run twice
                                Task { // runs on MainActor
                                    symLog.log("Withdraw HEAD KUDOS")
                                    let amount = Amount(currency:  DEMOCURRENCY, cent: 1100)
                                    try? await model.loadTestKudos(2, amount: amount)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(withDrawDisabled)
                        }.id("head1withdraw")
                        SettingsToggle(name: String("Set 2 seconds delay"),
                                      value: $developDelay.onChange({ delay in
                                                walletCore.developDelay = delay}),
                                        id1: "delay",
                                description: hideDescriptions ? nil : String("After each wallet-core action"))
                            .id("delay")
#if DEBUG
                        SettingsItem(name: String("Run Dev Experiment Refresh"), id1: "applyDevExperiment",
                              description: hideDescriptions ? nil : "dev-experiment/insert-pending-refresh") {
                            let title = "Refresh"
                            Button(title) {
                                Task { // runs on MainActor
                                    symLog.log("running applyDevExperiment Refresh")
                                    try? await model.setConfig(setTesting: true)
                                    try? await model.devExperimentT(talerUri: "taler://dev-experiment/start-block-refresh")
                                    try? await model.devExperimentT(talerUri: "taler://dev-experiment/insert-pending-refresh")
                                }
                            }
                            .buttonStyle(.bordered)
                        }.id("Refresh")
#endif
                        SettingsItem(name: String("Run Integration Test"), id1: "demo1test",
                              description: hideDescriptions ? nil : String("Perform basic test transactions")) {
                            let title = "Demo 1"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
                                    symLog.log("running integration test on demo")
                                    try? await model.runIntegrationTest(newVersion: false, test: false)
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
                                    try? await model.runIntegrationTest(newVersion: false, test: true)
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
                                    try? await model.runIntegrationTest(newVersion: true, test: false)
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
                                    try? await model.runIntegrationTest(newVersion: true, test: true)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }.id("test2runTest")
                        SettingsItem(name: String("Run Infinite Transaction Loop"), id1: "runInfinite",
                              description: hideDescriptions ? nil : String("Check DB in background")) {
                            let title = "Loop"
                            Button(title) {
                                checkDisabled = true    // don't run twice
                                Task { // runs on MainActor
                                    symLog.log("Running Infinite Transaction Loop")
                                    try? await model.testingInfiniteTransaction(delayMs: 10_000, shouldFetch: true)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(checkDisabled)
                        }.id("runInfiniteLoop")
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
//                            .disabled(didReset)
                        }.id("resetWallet")
                    }
                }
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .onAppear() {
            showDevelopItems = developerMode
            hideDescriptions = minimalistic
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

    } // body
}
// MARK: -
#if DEBUG
//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(stack: CallStack("Preview"), balances: <#Binding<[Balance]>#>, navTitle: "Settings")
//    }
//}
#endif
