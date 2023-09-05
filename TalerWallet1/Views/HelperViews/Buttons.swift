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
            .font(font ?? .talerTitle)
    }
}

struct QRButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "qrcode.viewfinder")
        }
        .font(font ?? .talerTitle)
        .accessibilityLabel("Scan QR codes")
    }
}

struct PlusButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
            .font(font ?? .talerTitle)
    }
}

struct ArrowUpButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.to.line")
        }
            .font(font ?? .talerTitle3)
    }
}

struct ArrowDownButton : View  {
    var font: Font?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.to.line")
        }
            .font(font ?? .talerTitle3)
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
            .font(font ?? .talerTitle)
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
                .font(.talerTitle3)
//                .font(narrow ? .talerTitle3 : .talerTitle2)
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
            HStack {
                Button("1000") {
                    Controller.shared.playSound(1000)
                }.padding()
                Button("1013") {
                    Controller.shared.playSound(1013)
                }.padding()
                Button("1008") {
                    Controller.shared.playSound(1008)
                }.padding()
                Button("1001") {
                    Controller.shared.playSound(1001)
                }.padding()
                Button("1018") {
                    Controller.shared.playSound(1018)
                }.padding()
            } // Single
            HStack {
                Button("1003") {
                    Controller.shared.playSound(1003)
                }.padding()
                Button("1004") {
                    Controller.shared.playSound(1004)
                }.padding()
                Button("1016") {
                    Controller.shared.playSound(1016)
                }.padding()
                Button("1022") {
                    Controller.shared.playSound(1022)
                }.padding()
                Button("1034") {
                    Controller.shared.playSound(1034)
                }.padding()
            } // Double
            HStack {
                Button("1023") {
                    Controller.shared.playSound(1023)
                }.padding()
                Button("1029") {
                    Controller.shared.playSound(1029)
                }.padding()
                Button("1014") {
                    Controller.shared.playSound(1014)
                }.padding()
                Button("1021") {
                    Controller.shared.playSound(1021)
                }.padding()
                Button("1031") {
                    Controller.shared.playSound(1031)
                }.padding()
            } // long single
            HStack {
                Button("1002") {
                    Controller.shared.playSound(1002) // == 7,12,15
                }.padding()
                Button("1006") {
                    Controller.shared.playSound(1006)
                }.padding()
                Button("1025") {
                    Controller.shared.playSound(1025)
                }.padding()
                Button("1026") {
                    Controller.shared.playSound(1026)
                }.padding()
                Button("1033") {
                    Controller.shared.playSound(1033)
                }.padding()
            } // Triple
            HStack {
                Button("1005") {
                    Controller.shared.playSound(1005) // 17
                }.padding()
                Button("1009") {
                    Controller.shared.playSound(1009)
                }.padding()
                Button("1010") {
                    Controller.shared.playSound(1010)
                }.padding()
            } // Double 2
            HStack {
                Button("1030") {
                    Controller.shared.playSound(1030)
                }.padding()
                Button("1035") {
                    Controller.shared.playSound(1035)
                }.padding()
                Button("1036") {
                    Controller.shared.playSound(1036)
                }.padding()
                Button("1027") {
                    Controller.shared.playSound(1027)
                }.padding()
            }
            HStack {
                Button("1020") {
                    Controller.shared.playSound(1020)
                }.padding()
                Button("1024") {
                    Controller.shared.playSound(1024)
                }.padding()
                Button("1032") {
                    Controller.shared.playSound(1032)
                }.padding()
                Button("1028") {
                    Controller.shared.playSound(1028)
                }.padding()
            }
            HStack {
                PlusButton() {
                }.padding()
                HamburgerButton() {
                }.padding()
                QRButton() {
                }.padding()
                ReloadButton(disabled: false) {
                }.padding()
                ReloadButton(disabled: true) {
                }.padding()
            }
            Button(String(localized: "Accept"), action: {
                Controller.shared.playSound(1028)
            })
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .padding(.horizontal)
        }
    }
}

#if DEBUG
//fileprivate struct ContentView: View {
//    @State var isOn = false
//    //The better route is to have a separate variable to control the animations
//    // This prevents unpleasant side-effects.
//    @State private var animate = false
//
//    var body: some View {
//        VStack {
//            Text(verbatim: "I don't change.")
//                .padding()
//            Button("Press me, I do change") {
//                isOn.toggle()
//                animate = false
//                // Because .opacity is animated, we need to switch it
//                // back so the button shows.
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                    animate = true
//                }
//            }
//            // In this case I chose to animate .opacity
//            .opacity(animate ? 1 : 0)
//            .animation(.easeIn, value: animate)
//            .frame(width: 300, height: 400)
//            // If you want the button to animate when the view appears, you need to change the value
//            .onAppear { animate = true }
//        }
//    }
//}
//fileprivate struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
#endif
