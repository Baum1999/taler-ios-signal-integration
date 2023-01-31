/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
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
import SwiftUI
import taler_swift
import SymLog

/*
 * Backup
 * Last backup: 5 hr. ago
 *
 *
 * Debug log
 * View/send internal log
 *
 *
 * Reset Wallet (dangerous!)
 * Throws away your money
 */

struct SettingsView: View {
    private let symLog = SymLogV(0)
    
    @EnvironmentObject var controller: Controller
    @AppStorage("developerMode") var developerMode: Bool = false
    @AppStorage("developDelay") var developDelay: Bool = false

    var showSidebar: () -> Void
    init(showSidebar: @escaping () -> Void) {
        self.showSidebar = showSidebar
    }

    @State private var checkDisabled = false
    @State private var withDrawDisabled = false

    var body: some View {
        symLog { NavigationView {
            List {
                NavigationLink {
                    ExchangeListView(viewModel: controller.exchangeModel)
                } label: {
                    SettingsItem(name: "Exchanges", description: "Manage list of exchanges known to this wallet") {}
                }
                SettingsToggle(name: "Developer Mode", value: $developerMode,
                               description: "More information intended for debugging")
                if developerMode {  // show or hide the following items
                    let walletCore = controller.walletCore
                    SettingsToggle(name: "Set 2 seconds delay", value: $developDelay,
                                   description: "After each wallet-core action")
                    .onChange(of: developDelay, perform: { developDelay in
                        walletCore.developDelay = developDelay
                    })

                    SettingsItem(name: "Withdraw KUDOS", description: "Get money for testing") {
                        Button("Withdraw") {
                            withDrawDisabled = true    // don't run twice
                            let testModel: ExchangeTestModel = ExchangeTestModel(walletCore: walletCore)
                            symLog.log("Withdrawing ")
                            testModel.loadTestKudos()
                        }
                        .buttonStyle(.bordered)
                        .disabled(withDrawDisabled)
                    }
                    SettingsItem(name: "Run Integration Test", description: "Check if wallet-core works") {
                        Button("Check") {
                            checkDisabled = true    // don't run twice
                            let testModel: ExchangeTestModel = ExchangeTestModel(walletCore: walletCore)
                            symLog.log("running integration test ")
                            testModel.runIntegrationTest()
                        }
                        .buttonStyle(.bordered)
                        .disabled(checkDisabled)
                    }
                    SettingsItem(name: "Save Logfile", description: "Help debugging wallet-core") {
                        Button("Save") {
                            symLog.log("Saving Log")
                            // FIXME: Save Logfile
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)
                    }
                    VStack {
                        SettingsItem(name: "App Version") {
                            Text("\(Bundle.main.releaseVersionNumberPretty)")
                        }
                        SettingsItem(name: "Wallet Core Version") {
                            Text("\(walletCore.versionInfo!.version)")
                        }
                        SettingsItem(name: "Wallet Core DevMode") {
                            Text("\(walletCore.versionInfo!.devMode ? "YES" : "NO")")
                        }
                        SettingsItem(name: "Supported Exchange Versions") {
                            Text("\(walletCore.versionInfo!.exchange)")
                        }
                        SettingsItem(name: "Supported Merchant Versions") {
                            Text("\(walletCore.versionInfo!.merchant)")
                        }
                        SettingsItem(name: "Used Bank") {
                            Text("\(walletCore.versionInfo!.bank)")
                        }
                    }
                }
            }
                .navigationTitle("Settings")
                .navigationBarItems(leading: HamburgerButton(action: showSidebar))
        } } // symLog
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView {
            
        }
    }
}
