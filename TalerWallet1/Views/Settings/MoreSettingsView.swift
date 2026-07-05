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

struct MoreSettingsView: View {
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
    @AppStorage("playSounds") var playSounds: Bool = false
    @AppStorage("pasteAutomatically") var pasteAutomatically: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true   // iOS 16 doesn't have NFC emulation
    @AppStorage("showQRauto17") var showQRauto17: Bool = false  // but iOS 17 does
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
    @AppStorage("oimEuro") var oimEuro: Bool = false
    @AppStorage("oimChart") var oimChart: Bool = false
    @AppStorage("payTokenAutomatically") var payTokenAutomatically: Bool = true
    @AppStorage("payMoneyAutomatically") var payMoneyAutomatically: Bool = false

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
        let list = List {
                let showQRstring = String(localized: "Show QR codes")
                let showQRhint = String(localized: "Automatically for P2P transactions")
                if #available(iOS 17.7, *) {
                    SettingsToggle(name: showQRstring, value: $showQRauto17, id1: "showQRautomatic",
                            description: showQRhint)
                } else {
                    SettingsToggle(name: showQRstring, value: $showQRauto16, id1: "showQRautomatic",
                            description: showQRhint)
                }
                SettingsQuadState(name: String(localized: "Preferred Appearance"),
                                 value: $preferredColorScheme,
                                   id1: "colorScheme")
                if controller.hapticCapability.supportsHaptics {
                    SettingsToggle(name: String(localized: "Haptics"), value: $useHaptics,
                                    id1: "haptics",
                            description: String(localized: "Vibration Feedback"))
                }

                SettingsToggle(name: String(localized: "Play Payment Sounds"), value: $playSounds,
                                id1: "playSounds",
                        description: String(localized: "When a transaction finished")) {_ in}

                SettingsToggle(name: String(localized: "Paste automatically"), value: $pasteAutomatically,
                                id1: "pasteAutomatically",
                        description: String(localized: "When this app activates")) {_ in}

                /// Backup
                let backupTitle = String(localized: "TitleBackup", defaultValue: "Backup / Restore")
                let backupDest = BackupView(stack: stack.push(backupTitle),
                                         navTitle: backupTitle)
                NavigationLink {
                    backupDest
                } label: {
                    SettingsItem(name: backupTitle, id1: "backup",
                          description: String(localized: "Backup your money")) {}
                }

                Section(header: Text(String(localized: "Pay automatically"))) {
                    SettingsToggle(name: String(localized: "Pay token automatically"), value: $payTokenAutomatically,
                                    id1: "payTokenAutomatically",
                            description: String(localized: "Skip confirmation to speed up", comment: "Pay automatically"))
                    SettingsToggle(name: String(localized: "Pay money automatically"), value: $payMoneyAutomatically,
                                    id1: "payMoneyAutomatically",
                            description: String(localized: "Skip confirmation to speed up", comment: "Pay automatically"))
                    if payMoneyAutomatically {
                        Text("Not yet implemented...")
                        Text("Allow automatic payments for chosen merchants only.")
                    }
                }
#if OIM
                SettingsToggle(name: String(localized: "OIM: Euro"), value: $oimEuro,
                                id1: "oimEuro",
                        description: String(localized: "OIM currency for KUDOS"))
#endif
#if OIM
                SettingsToggle(name: String(localized: "OIM: Chart"), value: $oimChart,
                                id1: "oimChart",
                        description: String(localized: "OIM history as chart"))
#endif

//                SettingsFont(title: String(localized: "Font:"), value: talerFontIndex, action: redraw)
//                    .id("font")
        }
            .id(listID)
            .listStyle(myListStyle.style).anyView
            .navigationTitle(navTitle)
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_SETTINGS2, stack: stack.push())
            }
        if #available(iOS 26.0, *) {
            list
        } else {
            list
                .padding(.bottom)
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
