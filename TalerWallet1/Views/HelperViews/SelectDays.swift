/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SelectDays: View {
    private let symLog = SymLogV(0)
    @Environment(\.isEnabled) private var isEnabled: Bool
    @AppStorage("developerMode") var developerMode: Bool = false

    @Binding var selected: UInt
    let maxExpiration: UInt

    func oneDayAction() -> Void {
        selected = 1
        symLog.log(selected)
    }

    func sevenDayAction() -> Void {
        selected = 7
        symLog.log(selected)
    }

    func thirtyDayAction() -> Void {
        selected = 30
        symLog.log(selected)
    }

    var body: some View {
        HStack {
            Button(action: oneDayAction) {
                Text(developerMode ? "3 Min." : "1 Day")
            }.buttonStyle(TalerButtonStyle(type: (selected == 1) ? .prominent : .bordered, dimmed: true))
                .disabled(!isEnabled)

            Button(action: sevenDayAction) {
                Text(developerMode ? "1 Hour" : "7 Days")
            }.buttonStyle(TalerButtonStyle(type: (selected == 7) ? .prominent : .bordered, dimmed: true))
                .disabled(!isEnabled || maxExpiration < 7)

            Button(action: thirtyDayAction) {
                Text(developerMode ? "1 Day" : "30 Days")
            }.buttonStyle(TalerButtonStyle(type: (selected == 30) ? .prominent : .bordered, dimmed: true))
                .disabled(!isEnabled || maxExpiration < 30)
        } // 3 buttons
    }
}

struct SelectDays_Previews: PreviewProvider {
    static var previews: some View {
        @State var expireDays: UInt = 1
        SelectDays(selected: $expireDays, maxExpiration: 20)
    }
}
