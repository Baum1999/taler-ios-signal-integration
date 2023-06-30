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
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
        }
            .font(font ?? .title)
    }
}

struct QRButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "qrcode.viewfinder")
        }
        .font(font ?? .title)
    }
}

struct PlusButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
            .font(font ?? .title)
    }
}

struct ArrowUpButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
            .font(font ?? .title3)
    }
}

struct ArrowDownButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
            .font(font ?? .title3)
    }
}

struct ReloadButton : View  {
    let disabled: Bool
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
            .font(font ?? .title)
            .disabled(disabled)
    }
}

struct TalerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    func disabled() -> Bool { !isEnabled }

    enum TalerButtonStyleType {
        case plain
        case bordered
        case prominent
    }
    var type: TalerButtonStyleType = .plain
    var dimmed: Bool = false
    var narrow: Bool = false
    var aligned: TextAlignment = .center

    public func makeBody(configuration: ButtonStyle.Configuration) -> some View {
            MyBigButton(type: type,
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
        return type == .plain ? WalletColors().fieldForeground :
            WalletColors().buttonForeColor(pressed: pressed,
                                           disabled: disabled(),
                                           prominent: type == .prominent)
    }
    func backColor(type: TalerButtonStyleType, pressed: Bool) -> Color {
//        return if type == .plain {
//            Color.clear
//        } else {
//            WalletColors().buttonBackColor(pressed: pressed,
//                                           disabled: disabled(),
//                                           prominent: type == .prominent)
//        }
        return type == .plain ? Color.clear :
            WalletColors().buttonBackColor(pressed: pressed,
                                           disabled: disabled(),
                                           prominent: type == .prominent)
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
        var type: TalerButtonStyleType
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
                .font(.title3)
//                .font(narrow ? .title3 : .title2)
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


struct Buttons_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HamburgerButton() {
                playSound(1000)
            }.padding()
            QRButton() {
                playSound(1001)
            }.padding()
            PlusButton() {
                playSound(1002) // == 7
            }.padding()
            HamburgerButton() {
                playSound(1003)
            }.padding()
            QRButton() {
                playSound(1004)
            }.padding()
            PlusButton() {
                playSound(1005)
            }.padding()
            HStack {
                ReloadButton(disabled: false) {
                    playSound(1006)
                }.padding()
                ReloadButton(disabled: true) {
                }.padding()
            }
            Button(String(localized: "Accept"), action: {
                playSound(1008)
            })
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .padding(.horizontal)
        }
    }
}

#if DEBUG
fileprivate struct ContentView: View {
    @State var isOn = false
    //The better route is to have a separate variable to control the animations
    // This prevents unpleasant side-effects.
    @State private var animate = false

    var body: some View {
        VStack {
            Text("I don't change.")
                .padding()
            Button("Press me, I do change") {
                isOn.toggle()
                animate = false
                // Because .opacity is animated, we need to switch it
                // back so the button shows.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    animate = true
                }
            }
            // In this case I chose to animate .opacity
            .opacity(animate ? 1 : 0)
            .animation(.easeIn, value: animate)
            .frame(width: 300, height: 400)
            // If you want the button to animate when the view appears, you need to change the value
            .onAppear { animate = true }
        }
    }
}
fileprivate struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
