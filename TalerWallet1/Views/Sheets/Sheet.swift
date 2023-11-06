/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog
import os.log

struct Sheet: View {
    private let symLog = SymLogV(0)
    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    @EnvironmentObject private var debugViewC: DebugViewC
    @AppStorage("talerFont") var talerFont: Int = 0

    var sheetView: AnyView

    let logger = Logger(subsystem: "net.taler.gnu", category: "Sheet")

    var cancelButton: some View {
        Button("Cancel") {
            logger.log("Cancel")
            dismissTop()
        }
    }

    var body: some View {
        let idString = debugViewC.sheetID > 0 ? String(debugViewC.sheetID)
                                              : ""      // show nothing if 0
        NavigationView {
            sheetView
                .navigationBarItems(leading: cancelButton)
                .navigationBarTitleDisplayMode(.automatic)
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(.stack)
        .talerNavBar(talerFont: talerFont)
        .overlay(alignment: .top) {
            // Show the viewID on top of the sheet's NavigationView
            Text(idString)
                .foregroundColor(.purple)
                .font(.system(size: 11))        // no accessibilityFont
                .monospacedDigit()
                .edgesIgnoringSafeArea(.top)
                .id("sheetID")
                .accessibilityLabel(Text("Sheet.ID.", comment: "AccessibilityLabel"))
                .accessibilityValue(idString)
        }
    }
}
