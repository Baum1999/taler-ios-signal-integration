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
    @AppStorage("useHaptics") var useHaptics: Bool = true
    @AppStorage("playSoundsI") var playSoundsI: Int = 1
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
//    @AppStorage("increaseContrast") var increaseContrast: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("useAuthentication") var useAuthentication: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true
    @AppStorage("showQRauto17") var showQRauto17: Bool = false
    @AppStorage("oimEuro") var oimEuro: Bool = false
    @AppStorage("oimChart") var oimChart: Bool = false

    @State private var hideDescriptions = false
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
                                                  navTitle: exchangesTitle)
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
                let biometryType = biometricService.biometryType()
                let biometryString = biometryType == .faceID ? String(localized: "Use FaceID")
                                   : biometryType == .touchID ? String(localized: "Use TouchID")
                                   : EMPTYSTRING
                if !biometryString.isEmpty {
                    SettingsToggle(name: biometryString, value: $useAuthentication, id1: "useFaceID",
                            description: minimalistic ? nil : String(localized: "Protect your money")) {
                        biometricService.isAuthenticated = false
                    }
//                } else {
//                    biometricService.isAuthenticated = false
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

#if DEBUG
                let showDiagnostic = true
#else
                let showDiagnostic = controller.diagnosticModeEnabled
#endif
                if showDiagnostic {
                    let devTitle = String(localized: "TitleDeveloper", defaultValue: "Developer")
                    let devDest = DebugSettingsView(stack: stack.push(devTitle),
                                                 navTitle: devTitle)
                    NavigationLink {        // whole row like in a tableView
                        devDest
                    } label: {
                        SettingsItem(name: devTitle, id1: "developer",
                                     description: hideDescriptions ? nil : String(localized: "Help debug this app...")) {}
                    }
                }
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .onAppear() {
            hideDescriptions = minimalistic
            DebugViewC.shared.setViewID(VIEW_SETTINGS, stack: stack.push())
        }
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
