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
    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("useAuthentication") var useAuthentication: Bool = false
    @AppStorage("pushNotifications") var pushNotifications: Bool = false

    @State private var listID = UUID()

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
                    SettingsItem(name: aboutStr, id1: "about", imageName: TALER_LOGO) {}
                }

                let exchangesTitle = String(localized: "TitleExchanges", defaultValue: "Payment Services")
                let exchangesDest = ExchangeListView(stack: stack.push(exchangesTitle),
                                                  navTitle: exchangesTitle)
                NavigationLink {        // whole row like in a tableView
                    exchangesDest
                } label: {
                    SettingsItem(name: exchangesTitle, id1: "exchanges", imageName: EXCHANGE_LOGO,
                          description: String(localized: "Manage payment services")) {}
                }
                let bankAccountsTitle = String(localized: "TitleBankAccounts", defaultValue: "Bank Accounts")
                let bankAccountsDest = BankListView(stack: stack.push(bankAccountsTitle),
                                                 navTitle: bankAccountsTitle)
                NavigationLink {        // whole row like in a tableView
                    bankAccountsDest
                } label: {
                    SettingsItem(name: bankAccountsTitle, id1: "bankAccounts",
                            imageName: "building.columns",
                          description: String(localized: "Your accounts for deposit")) {}
                }

                let biometryType = biometricService.biometryType()
                let hasFaceID = biometryType == .faceID
                let hasTouchID = biometryType == .touchID
                let biometryString = hasFaceID ? String(localized: "Use FaceID")
                                   : hasTouchID ? String(localized: "Use TouchID")
                                   : EMPTYSTRING
                if !biometryString.isEmpty {
                    SettingsToggle(name: biometryString,
                                  value: $useAuthentication,
                                    id1: "useFaceID",
                              imageName: hasFaceID ? "faceid" : "touchid", // 􀎽  􀟒
                            description: String(localized: "Protect your money")) { _ in
                        biometricService.isAuthenticated = false
                    }
//                } else {
//                    biometricService.isAuthenticated = false
                }

                SettingsToggle(name: String(localized: "Minimalistic"), value: $minimalistic, id1: "minimal",
                          imageName: "heart",                   // 􀊴
                        description: String(localized: "Omit text where possible"))

                SettingsToggle(name: String(localized: "Show Warnings"), value: $shouldShowWarning,
                                id1: "warnings",
                          imageName: "exclamationmark.triangle", // 􀇾
                        description: String(localized: "For Delete, Abandon & Abort buttons"))

              /// Report
                let reportTitle = String(localized: "TitleReport", defaultValue: "Report diagnostics")
                let reportDest = ReportView(stack: stack.push(reportTitle),
                                         navTitle: reportTitle)
                NavigationLink {
                    reportDest
                } label: {
                    SettingsItem(name: reportTitle, id1: "report",
                            imageName: "arrow.up.message",    // 􀜃
                          description: String(localized: "Help improve \(localizedAppName)")) {}
                }

#if DEBUG
                let showDiagnostic = true
#else
                let showDiagnostic = controller.diagnosticModeEnabled
#endif
                if showDiagnostic {
                    let devTitle = String(localized: "TitleDeveloper", defaultValue: "Developer")
                    let devDest = DebugSettingsView(stack: stack.push(devTitle),
                                                 navTitle: devTitle)
                    NavigationLink {
                        devDest
                    } label: {
                        SettingsItem(name: devTitle, id1: "developer",
                                imageName: "hammer",        // 􀙄
                              description: String(localized: "Help debug \(localizedAppName)")) {}
                    }
                }

                let moreItem = String(localized: "TitleMore", defaultValue: "More")
                let moreTitle = String(localized: "TitleMoreSettings", defaultValue: "More Settings")
                let moreDest = MoreSettingsView(stack: stack.push(moreTitle),
                                             navTitle: moreTitle)
                NavigationLink {
                    moreDest
                } label: {
                    SettingsItem(name: moreItem, id1: "more",
                            imageName: "ellipsis",          // 􀍠
                          description: nil) {}
                }
            }
            .padding(.bottom)
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .onAppear() {
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
