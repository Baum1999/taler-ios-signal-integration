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
    @AppStorage("playSoundsI") var playSoundsI: Int = 1
    @AppStorage("playSoundsB") var playSoundsB: Bool = false
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("showQRauto16") var showQRauto16: Bool = true
    @AppStorage("showQRauto17") var showQRauto17: Bool = false
    @AppStorage("oimEuro") var oimEuro: Bool = false
    @AppStorage("oimChart") var oimChart: Bool = false

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
                let showQRstring = String(localized: "Show QR codes")
                let showQRhint = String(localized: "Automatically for P2P transactions")
                if #available(iOS 17.7, *) {
                    SettingsToggle(name: showQRstring, value: $showQRauto17, id1: "showQRautomatic",
                            description: showQRhint)
                } else {
                    SettingsToggle(name: showQRstring, value: $showQRauto16, id1: "showQRautomatic",
                            description: showQRhint)
                }

                if controller.hapticCapability.supportsHaptics {
                    SettingsToggle(name: String(localized: "Haptics"), value: $useHaptics,
                                    id1: "haptics",
                                   description: String(localized: "Vibration Feedback"))
                }

                SettingsToggle(name: String(localized: "Play Payment Sounds"), value: $playSoundsB,
                                id1: "playSounds",
                        description: String(localized: "When a transaction finished")) {_ in}

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
