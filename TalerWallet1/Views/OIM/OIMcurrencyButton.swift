/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate
struct OIMbuttonStyle: ButtonStyle {

    public func makeBody(configuration: OIMbuttonStyle.Configuration) -> some View {
        configuration.label
//            .foregroundColor(.white)
//            .padding(15)
//            .background(RoundedRectangle(cornerRadius: 5).fill(color))
//            .compositingGroup()
//            .shadow(color: .black, radius: 3)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

fileprivate
struct OIMcurrencyImage {
    let image: Image
    let oWidth: CGFloat
    let oHeight: CGFloat

    init(_ name: String?) {
        if let name, let uiImage = UIImage(named: name) {
            self.oWidth = uiImage.size.width
            self.oHeight = uiImage.size.height
            self.image = Image(uiImage: uiImage)
        } else {
            self.image = Image(systemName: "exclamationmark.triangle")
            self.oWidth = 300
            self.oHeight = 300
        }
    }
}

fileprivate
struct OIMmod: AnimatableModifier {
    let value: UInt64
    let name: String?
    let flippedName: String?
    let availableVal: UInt64
    let canEdit: Bool
    let invisible: Bool
    let isFlipped: Bool
    var pct: CGFloat
    let action: () -> Void

    var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }

    func body(content: Content) ->  some View {
        let shadow = (3 - 8) * pct + 8
        let currencyImage = OIMcurrencyImage(name)
        let oWidth = currencyImage.oWidth / 4
        let oHeight = currencyImage.oHeight / 4
        let image = currencyImage.image
                .resizable()
                .scaledToFit()

        let valueImage = image
            .rotation3DEffect(.degrees(isFlipped ? 90 : 0),
                              axis: (x: 0.0, y: 1.0, z: 0.0))
        let backImage = Group {
            if let flippedName {
                let flippedImage = OIMcurrencyImage(flippedName)
//                            let _ = print("  OIMmod", isFlipped, value, flippedName)
                flippedImage.image
                    .resizable()
                    .scaledToFit()
            } else {
//                if isFlipped {
//                            let _ = print("  OIMmod no image", isFlipped, value, flippedName)
//                }
                EmptyView()
            }
        }
            .rotation3DEffect(.degrees(isFlipped ? 0 : -90),
                              axis: (x: 0.0, y: 1.0, z: 0.0))
        let animatedImage = ZStack {
            valueImage
                .animation(isFlipped ? .linear : .linear.delay(0.35), value: isFlipped)
            backImage
                .animation(isFlipped ? .linear.delay(0.35) : .linear, value: isFlipped)
        }

        return Group {
            if invisible {
                image.opacity(0)
            } else if !canEdit || availableVal < value {
                animatedImage
                    .opacity(canEdit ? 0.5 : 1.0)
            } else {
                Button(action: action) {        // TODO: disable after tapped
                    animatedImage
                }
                .buttonStyle(OIMbuttonStyle())
            }
        } // Group
//            .frame(width: (isFlipped != 0 ? 0.7 * oWidth : oWidth),
//                  height: (isFlipped != 0 ? 0.7 * oHeight : oHeight))
            .frame(width: oWidth, height: oHeight)
            .shadow(radius: shadow)
            .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))         // TODO: currency name
    }
}
// MARK: -
/// renders 1 denomination from a currency
struct OIMcurrencyButton: View {
    let stack: CallStack
    let fund: OIMfund
    let currency: OIMcurrency
    let availableVal: UInt64
    let canEdit: Bool
    var pct: CGFloat
    let action: () -> Void

    @EnvironmentObject private var cash: OIMcash

    func imgName(_ value: UInt64?) -> String? {
        if let value {
            return value > currency.bankCoins[0] ? currency.noteName(value)
                                                 : currency.coinName(value)
        }
        return nil
    }

    var body: some View {
        let currency = cash.currency
        let value = fund.value
        let isMorphing = fund.morphTicker != nil
        let flippedVal = fund.flippedVal
        // Use EmptyView, because the modifier actually ignores
        // the value passed to its body() function.
        let isFlipped: Bool = switch fund.state {
            case .morphed:  true
            case .flipping: true
            default:        false
        }
//    if fund.id == 6 {
//        let _ = print("Fund", fund.id, value, fund.state, flippedVal)
//    }
        EmptyView().modifier(OIMmod(value: value,
                                     name: imgName(value),
                              flippedName: imgName(flippedVal),
                             availableVal: availableVal,
                                  canEdit: canEdit && !isMorphing,  //    cannot edit morphing funds
                                invisible: fund.state == .hiding,
                                isFlipped: isFlipped && flippedVal != nil,
                                      pct: pct,
                                   action: action))
    }
}

// MARK: -
//#Preview {
//    OIMcurrencyView()
//}
