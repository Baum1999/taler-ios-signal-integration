/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import Foundation

extension ShapeStyle where Self == Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

struct HamburgerButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
//            Image(systemName: "sidebar.squares.leading")
        }
        .accessibilityFont(.title)
        .accessibilityLabel("Main Menu")
    }
}

struct QRButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "qrcode.viewfinder")
        }
        .accessibilityFont(.title)
        .accessibilityLabel("Scan QR codes")
    }
}

struct PlusButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .accessibilityFont(.title)
        .accessibilityLabel("Add...")
    }
}

struct ArrowUpButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
        .accessibilityFont(.title2)
        .accessibilityLabel("Scroll up")
    }
}

struct ArrowDownButton : View  {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
        .accessibilityFont(.title2)
        .accessibilityLabel("Scroll down")
    }
}

struct ReloadButton : View  {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
        .accessibilityFont(.title)
        .accessibilityLabel("Reload")
        .disabled(disabled)
    }
}

struct TalerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    func disabled() -> Bool { !isEnabled }

    enum TalerButtonStyleType {
        case plain
        case balance
        case bordered
        case prominent
    }
    var type: TalerButtonStyleType = .plain
    var dimmed: Bool = false
    var narrow: Bool = false
    var aligned: TextAlignment = .center

    public func makeBody(configuration: ButtonStyle.Configuration) -> some View {
            MyBigButton(//type: type,
                   foreColor: foreColor(type: type, pressed: configuration.isPressed),
                   backColor: backColor(type: type, pressed: configuration.isPressed),
                      dimmed: dimmed,
               configuration: configuration,
                    disabled: disabled(),
                      narrow: narrow,
                     aligned: aligned)
    }

    func foreColor(type: TalerButtonStyleType, pressed: Bool) -> Color {
//        return if type == .plain {
//            WalletColors().fieldForeground
//        } else {
//            WalletColors().buttonForeColor(pressed: pressed,
//                                          disabled: disabled(),
//                                         prominent: type == .prominent)
//        }
        return type == .plain ? WalletColors().fieldForeground :      // primary text color
            WalletColors().buttonForeColor(pressed: pressed,
                                          disabled: disabled(),
                                         prominent: type == .prominent,
                                           balance: type == .balance)
    }
    func backColor(type: TalerButtonStyleType, pressed: Bool) -> Color {
//        return if type == .plain {
//            Color.clear
//        } else {
//            WalletColors().buttonBackColor(pressed: pressed,
//                                           disabled: disabled(),
//                                           prominent: type == .prominent)
//        }
        return type == .plain && !pressed ? Color.clear :
            WalletColors().buttonBackColor(pressed: pressed,
                                          disabled: disabled(),
                                         prominent: type == .prominent,
                                           balance: type == .balance)
    }

    struct BackgroundView: View {
        let color: Color
        let dimmed: Bool
        var body: some View {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(color)
            .opacity(dimmed ? 0.6 : 1.0)
        }
    }

    struct MyBigButton: View {
//        var type: TalerButtonStyleType
        let foreColor: Color
        let backColor: Color
        let dimmed: Bool
        let configuration: ButtonStyle.Configuration
        let disabled: Bool
        let narrow: Bool
        let aligned: TextAlignment

        var body: some View {
            let aligned2: Alignment = (aligned == .center) ? Alignment.center
                                    : (aligned == .leading) ? Alignment.leading
                                    : Alignment.trailing
            configuration.label
                .multilineTextAlignment(aligned)
                .accessibilityFont(.title3)
//                                  narrow ? .title3 : .title2
                .frame(minWidth: 0, maxWidth: narrow ? nil : .infinity, alignment: aligned2)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .foregroundColor(foreColor)
                .background(BackgroundView(color: backColor, dimmed: dimmed))
                .contentShape(Rectangle())      // make sure the button can be pressed even if backgroundColor == clear
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.spring(response: 0.1), value: configuration.isPressed)
                .disabled(disabled)
        }
    }
}

#if DEBUG
fileprivate struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let testButtonTitle = String("Placeholder")
        Button(testButtonTitle) {}
            .buttonStyle(TalerButtonStyle(type: .balance, aligned: .trailing))
    }
}
#endif
