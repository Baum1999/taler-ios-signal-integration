/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

public struct WalletColors {

    let tint = Color(.tintColor)
    let gray1 = Color(.systemGray)
    let gray2 = Color(.systemGray2)
    let gray3 = Color(.systemGray3)
    let gray4 = Color(.systemGray4)
    let gray5 = Color(.systemGray5)
    let gray6 = Color(.systemGray6)

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
          : disabled ? gray5
         : prominent ? tint
           : pressed ? gray5 : gray4
    }

    var backgroundColor: Color {
        gray6
    }

    var sideBackground: Color {
        gray5
    }

    var fieldForeground: Color {              // text color
        Color.primary
    }
    var fieldBackground: Color {
        Color(.systemBackground)
    }

    var incompleteColor: Color {
        gray1
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
