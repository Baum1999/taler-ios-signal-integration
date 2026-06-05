/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct SelectDays: View {
    private let symLog = SymLogV(0)
    @AppStorage("minimalistic") var minimalistic: Bool = false
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @Binding var selected: UInt
    let maxExpirationHours: UInt64
    let defaultExpirationHours: UInt64
    let outgoing: Bool

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
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let maxExpiration = maxExpirationHours / 24
        let chooseExpiration = Section {   // (alignment: .leading)
            Text("Expires in:")
                .accessibilityLabel(Text("Choose the expiration duration", comment: "a11y"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityRemoveTraits(.isStaticText)
                .talerFont(.title3)
            HStack {
                Button(action: oneDayAction) {
                    if developerMode {
                        Text(verbatim: "3 Min.")
                    } else {
                        Text("\(ONEDAY) Day", comment: "1 Day, might get plural (e.g. 2..3 Days), 4 letters max., abbreviate if longer")     // TODO: Plural
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == ONEDAY) ? .prominent : .bordered,
                                             dimmed: true))
                    .accessibilityAddTraits(selected == ONEDAY ? .isSelected : [])

                Button(action: sevenDayAction) {
                    if developerMode {
                        Text(verbatim: "1 Hour")
                    } else {
                        Text("\(SEVENDAYS) Days", comment: "7 Days, always plural (3..9), 4 letters max., abbreviate if longer")
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == SEVENDAYS) ? .prominent : .bordered, dimmed: true,
                                              disabled: maxExpiration < SEVENDAYS))
                    .accessibilityAddTraits(selected == SEVENDAYS ? .isSelected : [])
                    .disabled(maxExpiration < SEVENDAYS)

                Button(action: thirtyDayAction) {
                    if developerMode {
                        Text(verbatim: "1 Day")
                    } else {
                        let thirtyDays = String(localized: "thirtyDays", defaultValue: "\(THIRTYDAYS) Days", comment: "30 Days, always plural (10..30), 4 letters max., abbreviate if longer")
                        Text(thirtyDays)
                    }
                }.buttonStyle(TalerButtonStyle(type: (selected == THIRTYDAYS) ? .prominent : .bordered, dimmed: true,
                                              disabled: maxExpiration < THIRTYDAYS))
                    .accessibilityAddTraits(selected == THIRTYDAYS ? .isSelected : [])
                    .disabled(maxExpiration < THIRTYDAYS)
            } // 3 buttons
            if !minimalistic {
                Text(outgoing ? "The payment service will send your money back if it won't get collected on time, or when you abort the operation."
                              : "This request will be cancelled if it doesn't get paid on time, or when you abort the operation.")
                .talerFont(.body)
            }
        }
#if TALER_WALLET
        chooseExpiration
#else
        if developerMode {
            chooseExpiration
        } else if outgoing {
            if !minimalistic {
                Section {   // (alignment: .leading)
                    Text(defaultExpirationHours < 49 ? "The payment service will send your money back if it won't get collected in the next \(defaultExpirationHours) hours, or when you abort the operation."
                    : "The payment service will send your money back if it won't get collected in the next \(defaultExpirationHours/24) days, or when you abort the operation.")
                    .talerFont(.body)
                }
            }
        } else {
            chooseExpiration
        }
#endif
    }
}
// MARK: -
#if DEBUG
struct SelectDays_Previews: PreviewProvider {
    static var previews: some View {
        @State var expireDays: UInt = 1
        SelectDays(selected: $expireDays, maxExpirationHours: 30*24, defaultExpirationHours: 7, outgoing: false)
    }
}
#endif
