/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct Sheet: View {
    private let symLog = SymLogV()
    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    @EnvironmentObject private var debugViewC: DebugViewC

    var sheetView: AnyView

    var cancelButton: some View {
        Button("Cancel") {
            print(dismiss)  // TODO: delete this line
            dismissTop()
        }
    }

    var body: some View {
        let idString = debugViewC.sheetID > 0 ? String(debugViewC.sheetID) : ""
        NavigationView {
            sheetView
                .navigationBarItems(leading: cancelButton)
                .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        }
        .overlay(alignment: .top) {
            // Show the viewID on top of the sheet's NavigationView
            Text(idString)
                .font(.caption2)
                .foregroundColor(.purple)
                .edgesIgnoringSafeArea(.top)
                .id("sheetID")
        }
    }
}
// MARK: -
//struct Sheet_Previews: PreviewProvider {
//    static var previews: some View {
//
//    }
//}
