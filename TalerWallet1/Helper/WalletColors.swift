/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

fileprivate let grouped = true

struct FullBackground: View {
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0

    @available(iOS 17.0, *)
    @MainActor
    var liquidView : some View {
        // Ensure we always start with a different view
        let startDate = Date() - Double.random(in: 1...999)
        let size = UIScreen.screenSize
        let view = TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            Rectangle()
                .colorEffect(
                    ShaderLibrary.liquidBack(
                        .float2(size.width, size.height),
                        .float(Float(elapsed))
                    )
                )
        }
        return view.ignoresSafeArea()
    }

    var backgroundView: some View {
        WalletColors().backgroundColor.ignoresSafeArea()
    }

    var body: some View {
        if preferredColorScheme == 3, #available(iOS 17.0, *) {
            liquidView
        } else {
            backgroundView
        }
    }
}
public struct WalletColors {
    @AppStorage("minimalistic") private var minimalistic: Bool = false

//    let tint = Color(.tintColor)
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

    let attention = Color.red       // TODO: WalletColors().errorColor
    let confirm = Color.yellow      // TODO: WalletColors().warningColor

    // TODO: In Japan, negative is blue, and positive is red
    let positive = Color.green
    let negative = Color.red

    func buttonForeColor(pressed: Bool,
                        disabled: Bool,
                          scheme: ColorScheme,
                        contrast: ColorSchemeContrast,
                       prominent: Bool = false) -> Color {
            disabled ? gray2
        : !prominent ? primaryAccent
        : scheme == .dark ? primary(contrast)
           : pressed ? gray6 : Color.white
    }

    func buttonBackColor(pressed: Bool,
                        disabled: Bool,
                       prominent: Bool = false) -> Color {
            disabled ? gray7
         : prominent ? primaryAccent
           : pressed ? gray4 : gray5
    }

    func primary(_ contrast: ColorSchemeContrast = .standard) -> Color {
        return contrast == .increased ? .primary
                                      : Color("Primary")
    }

    func secondary(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast = .standard) -> Color {
        return contrast == .increased ? .primary            // WCAG AAA for any scheme
                       : minimalistic ? .secondary          // not enough contrast
                    : scheme == .dark ? .secondary          // WCAG AA for dark scheme
                                      : Color(.darkGray)    // WCAG AA for light scheme
    }

    var labelColor: Color {
        Color(UIColor.label)
    }

    var backgroundColor: Color {
        grouped ? Color(.systemGroupedBackground)
                : Color(.systemBackground)
    }

    var secondaryBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }

    var sideBackgroundColor: Color {
        gray6
    }

    func pickerSelected(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) -> Color {
        return contrast == .increased ? (scheme == .dark ? gray2 : gray3)
                                      : (scheme == .dark ? gray3 : gray4)
    }

    var pickerBackground: Color {
        gray7
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

    var errorColor: Color {
        Color("Error")
    }

    var primaryAccent: Color {
        Color("Taler")
    }

    func pendingColor(_ incoming: Bool) -> Color {
        incoming ? primaryAccent    // Color("PendingIncoming")
                 : primary()        // Color("PendingOutgoing")
    }

    func transactionColor(_ incoming: Bool) -> Color {
        incoming ? primaryAccent    // Color("Incoming")
                 : primary()        // Color("Outgoing")
    }
}
