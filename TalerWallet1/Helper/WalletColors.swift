/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

fileprivate let grouped = true

public struct WalletColors {
    @AppStorage("minimalistic") var minimalistic: Bool = false

    let tint = Color(.tintColor)
    let gray1 = Color(.systemGray)          // uncompleted
    let gray2 = Color(.systemGray2)         // disabled Fore
    let gray3 = Color(.systemGray3)
    let gray4 = Color(.systemGray4)
    let gray5 = Color(.systemGray5)
    let gray6 = Color(.systemGray6)
    let gray7 = grouped ? Color(.tertiarySystemGroupedBackground)
                        : Color(.tertiarySystemBackground)        // enabled Back
    let gray8 = grouped ? Color(.secondarySystemGroupedBackground)
                        : Color(.secondarySystemBackground)       // disabled Back

    func buttonForeColor(pressed: Bool, disabled: Bool,
                       prominent: Bool = false, balance: Bool = false) -> Color {
             balance ? Color.primary
          : disabled ? gray2
        : !prominent ? tint
           : pressed ? gray6 : gray5
    }

    func buttonBackColor(pressed: Bool, disabled: Bool,
                       prominent: Bool = false, balance: Bool = false) -> Color {
             balance ? (pressed ? gray5 : gray6)
          : disabled ? gray7
         : prominent ? tint
           : pressed ? gray4 : gray5
    }

    func secondary(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) -> Color {
        return contrast == .increased ? .primary            // WCAG AAA for any scheme
                       : minimalistic ? .secondary          // not enough contrast
                    : scheme == .dark ? .secondary          // WCAG AA for dark scheme
                                      : Color(.darkGray)    // WCAG AA for light scheme
    }

    var backgroundColor: Color {
        grouped ? Color(.systemGroupedBackground)
                : Color(.systemBackground)
    }

    var sideBackground: Color {
        gray6
    }

    var fieldForeground: Color {              // text color
        Color.primary
    }
    var fieldBackground: Color {
        gray8
    }

    var uncompletedColor: Color {
        // used in TransactionRowView
        gray1
    }
    func errorColor() -> Color {
        Color("Error")
    }
    func pendingColor(_ incoming: Bool) -> Color {
        incoming ? Color("PendingIncoming")
                 : Color("PendingOutgoing")
    }
    func transactionColor(_ incoming: Bool) -> Color {
        incoming ? Color("Incoming")
                 : Color("Outgoing")
    }

}
