/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import os.log

struct Sheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    var sheetView: AnyView

    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    @EnvironmentObject private var debugViewC: DebugViewC
    @EnvironmentObject private var model: WalletModel
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    let logger = Logger(subsystem: "net.taler.gnu", category: "Sheet")

    var cancelButton: some View {
        Button("Cancel") {
            logger.log("Cancel")
            dismissTop(stack.push())
        }
    }

    var body: some View {
        let idString = debugViewC.sheetID > 0 ? String(debugViewC.sheetID)
                                              : EMPTYSTRING      // show nothing if 0
        NavigationView {
            Group {
                if let error2 = model.error2 {
                    ErrorSheet(data: error2, devMode: developerMode) {
                        logger.log("ErrorSheet dismissTop")
                        dismissTop(stack.push())
                    }
                } else {
                    sheetView
//                        .navigationBarItems(leading: cancelButton)
                }
            }
                .navigationBarTitleDisplayMode(.automatic)
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(.stack)
        .talerNavBar(talerFontIndex: talerFontIndex)
        .overlay(alignment: .top) {
            // Show the viewID on top of the sheet's NavigationView
            Text(idString)
                .foregroundColor(.purple)
                .font(.system(size: 11))        // no talerFont
                .monospacedDigit()
                .edgesIgnoringSafeArea(.top)
                .id("sheetID")
                .accessibilityLabel(Text("Sheet.ID.", comment: "VoiceOver"))
                .accessibilityValue(idString)
        }
        .onDisappear {
            symLog.log("❗️❗️Sheet onDisappear")
        }
    }
}
