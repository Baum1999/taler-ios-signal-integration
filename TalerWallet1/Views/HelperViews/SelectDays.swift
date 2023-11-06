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
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @Binding var selected: UInt
    let maxExpiration: UInt

    func oneDayAction() -> Void {
        selected = ONEDAY
        symLog.log(selected)
    }

    func sevenDayAction() -> Void {
        selected = SEVENDAYS
        symLog.log(selected)
    }

    func thirtyDayAction() -> Void {
        selected = THIRTYDAYS
        symLog.log(selected)
    }

    var body: some View {
        let selectedStr = String(localized: "selected", comment: "VoiceOver hint which button is selected")

        Section {   // (alignment: .leading)
            Text("Expires in:")
                .accessibilityLabel("Choose the expiration duration")
                .accessibilityAddTraits(.isHeader)
                .accessibilityRemoveTraits(.isStaticText)
                .accessibilityFont(.title3)
            HStack {
                Button(action: oneDayAction) {
                    if developerMode {
                        Text(verbatim: "3 Min.")
                    } else {
                        Text("\(ONEDAY) Day", comment: "1 Day, might get plural (e.g. 2..3 Days), 4 letters max., abbreviate if longer")     // TODO: Plural
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == ONEDAY) ? .prominent : .bordered, dimmed: true))
                    .accessibilityValue((selected == ONEDAY) ? selectedStr : EMPTYSTRING)
                    .disabled(!isEnabled)

                Button(action: sevenDayAction) {
                    if developerMode {
                        Text(verbatim: "1 Hour")
                    } else {
                        Text("\(SEVENDAYS) Days", comment: "7 Days, always plural (3..9), 4 letters max., abbreviate if longer")
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == SEVENDAYS) ? .prominent : .bordered, dimmed: true))
                    .accessibilityValue((selected == SEVENDAYS) ? selectedStr : EMPTYSTRING)
                    .disabled(!isEnabled || maxExpiration < SEVENDAYS)

                Button(action: thirtyDayAction) {
                    if developerMode {
                        Text(verbatim: "1 Day")
                    } else {
                        Text("\(THIRTYDAYS) Days", comment: "30 Days, always plural (10..30), 4 letters max., abbreviate if longer")
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == THIRTYDAYS) ? .prominent : .bordered, dimmed: true))
                    .accessibilityValue((selected == THIRTYDAYS) ? selectedStr : EMPTYSTRING)
                    .disabled(!isEnabled || maxExpiration < THIRTYDAYS)
            } // 3 buttons
        }
    }
}
// MARK: -
#if DEBUG
struct SelectDays_Previews: PreviewProvider {
    static var previews: some View {
        @State var expireDays: UInt = 1
        SelectDays(selected: $expireDays, maxExpiration: 20)
    }
}
#endif
