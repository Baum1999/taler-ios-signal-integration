/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog
import LocalConsole

struct DebugSettingsView: View {
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
    @AppStorage("logTransactions") var logTransactions: Bool = false
    @AppStorage("useHaptics") var useHaptics: Bool = true
    @AppStorage("developDelay") var developDelay: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("localConsoleL") var localConsoleL: Bool = false                // for Logs
    @AppStorage("localConsoleO") var localConsoleO: Int = 0                     // for Observability
    @AppStorage("debugViews") var debugViews: Bool = false

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false
    @State private var showDevelopItems = false
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
                controller.balances.removeAll()
            }
        }
    }
    @State private var listID = UUID()

    func setDelay(_ doDelay: Bool, for walletCore: WalletCore) async {
        symLog.log(doDelay ? "wallet-core delaying by 5 seconds"
                           : "wallet-core stop delaying")
        let delayTime = doDelay ? TCDELAY : 0
        try? await model.devExperimentT("taler://dev-experiment/start-tc?delay_resp=\(delayTime)")
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        let list = List {
                SettingsToggle(name: String("Developer Mode"), value: $developerMode,
                                id1: "devMode",
                        description: String("More information intended for debugging")) { newVal in
                    withAnimation(Animation.linear.delay(0.8)) { showDevelopItems = developerMode }
                    Task {
                        symLog.log((newVal ? "enabling" : "disabling") + " applyDevExperiment")
                        try? await model.setConfig(setTesting: newVal)
                        if newVal && developDelay == true {
                            await setDelay(true, for: walletCore)
                        }
                    }
                }
                if showDevelopItems {
#if DEBUG
                    SettingsToggle(name: String("Log Transactions"), value: $logTransactions,
                                    id1: "logTransactions",
                            description: String("full log with all tx"))
#endif
                    if #available (iOS 16.0, *) {
                        let localConsStr = String("on LocalConsole")
                        let observability = String("Observe walletCore")
                        SettingsTriState(name: observability, value: $localConsoleO.onChange({ isObserving in
                            walletCore.isObserving = isObserving}),
                                          id1: "observe",
                                  description: localConsStr) { _ in
                            let consoleManager = LCManager.shared
                            consoleManager.isVisible = localConsoleO != 0 || localConsoleL
                            consoleManager.clear()
                        }
                        let showLogs = String("Show logs")
                        SettingsToggle(name: showLogs, value: $localConsoleL.onChange({ isLogging in
                            walletCore.isLogging = isLogging}),
                                        id1: "localConsoleL",
                                description: localConsStr) { _ in
                            let consoleManager = LCManager.shared
                            consoleManager.isVisible = localConsoleO != 0 || localConsoleL
                            consoleManager.clear()
                        }
                    }
                    SettingsToggle(name: String("Set 5 seconds delay"),
                                  value: $developDelay.onChange({ delay in
                        Task {
                            try await setDelay(delay, for: walletCore)
                        }
                    }),
                                    id1: "delay",
                            description: String("After each network call"))
                        .id("delay")
                    SettingsToggle(name: String(localized: "Show view sizes"), value: $debugViews,
                                    id1: "debugViews",
                            description: String(localized: "Debug view layout and flickering"))
                        .id("debugViews")
#if DEBUG
                    let banks = [//"stage.taler-ops.ch",    <= never has a bank!
//                                 "glstest.taler.net",
                                 "taler.fdold.eu", "regio-taler.fdold.eu",
                                 "taler.grothoff.org", "taler.ar",
                                 "head.taler.net", "test.taler.net", "demo.taler.net", "kyctest.taler.net"]
                    ForEach(banks, id: \.self) { bank in
                        let urlStr = "https://bank." + bank
                        Link(bank, destination: URL(string: urlStr)!)
                    }
#endif
                } // showDevelopItems
                    SettingsItem(name: String("DEMO"), id1: "demo1with",
                          description: String("Get money for testing")) {
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
                          description: String("Get money for testing")) {
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
                if showDevelopItems {
                    SettingsItem(name: String("HEAD"), id1: "head1with",
                          description: String("Get money for testing")) {
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
#if DEBUG
                    SettingsItem(name: String("Run Dev Experiment Refresh"),
                                  id1: "applyDevExperiment",
                          description: "dev-experiment/insert-pending-refresh") {
                        let title = "Refresh"
                        Button(title) {
                            Task { // runs on MainActor
                                symLog.log("running applyDevExperiment Refresh")
                                try await model.setConfig(setTesting: true)
                                try await model.devExperimentT("taler://dev-experiment/start-block-refresh")
                                try await model.devExperimentT("taler://dev-experiment/insert-pending-refresh")
                            }
                        }
                        .buttonStyle(.bordered)
                    }.id("Refresh")
#endif
                    SettingsItem(name: String("Run Integration Test"),
                                  id1: "demo1test",
                          description: String("Perform basic test transactions")) {
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
                    SettingsItem(name: String("Run Integration Test"),
                                  id1: "test1test",
                          description: "Perform basic test transactions") {
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
                    SettingsItem(name: String("Run Integration Test V2"),
                                  id1: "demo2test",
                          description: String("Perform more test transactions")) {
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
                    SettingsItem(name: String("Run Integration Test V2"),
                                  id1: "test2test",
                          description: String("Perform more test transactions")) {
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
                    SettingsItem(name: String("Run Infinite Transaction Loop"),
                                  id1: "runInfinite",
                          description: String("Check DB in background")) {
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
#if false
                    SettingsItem(name: String("Save Logfile"), id1: "save",
                          description: String("Help debugging wallet-core")) {
                        Button("Save") {
                            symLog.log("Saving Log")
                            // FIXME: Save Logfile
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)
                    }.id("saveLog")
#endif
                    SettingsItem(name: String("Reset Wallet"), id1: "reset",
                          description: String("Throw away all your money")) {
                        Button("Reset") {
                            showResetAlert = true
                        }
                        .buttonStyle(.bordered)
//                        .disabled(didReset)
                    }.id("resetWallet")
                }
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
            .navigationTitle(navTitle)
            .onAppear() {
                showDevelopItems = developerMode
                DebugViewC.shared.setViewID(VIEW_SETTINGS3, stack: stack.push())
            }
            .onDisappear() {
                checkDisabled = false    // reset
                withDrawDisabled = false
            }
            .alert("Reset Wallet", isPresented: $showResetAlert,
                actions: { dismissAlertButton
                           resetButton },
                message: { Text(verbatim: "Are you sure you want to reset your wallet?\nThis cannot be reverted, all money will be lost.") })
        if #available(iOS 26.0, *) {
            list
        } else {
            list
                .padding(.bottom)
        }
    } // body
}
