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
    let name: String?
    let flippedName: String?
    let flipTime: TimeInterval
    let isFlipped: Bool
    let flipBack: Bool            // if true, then don't animate flipping back
    let disabled: Bool
    let unavailable: Bool
    let invisible: Bool
    var pct: CGFloat
    let action: () -> Void

    var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }

    func body(content: Content) ->  some View {
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
                flippedImage.image
                    .resizable()
                    .scaledToFit()
            } else {
                EmptyView()
            }
        }
            .rotation3DEffect(.degrees(isFlipped ? 0 : -90),
                              axis: (x: 0.0, y: 1.0, z: 0.0))

        let linTime: Animation = .linear(duration:flipTime)
        let frontAnimation = isFlipped ? linTime
                                       : linTime.delay(flipTime)
        let backAnimation  = isFlipped ? linTime.delay(flipTime)
                                       : linTime
        let animatedImage = ZStack {
            valueImage
                .animation(flipBack ? nil : frontAnimation, value: isFlipped)
            backImage
                .animation(flipBack ? nil : backAnimation, value: isFlipped)
        }

        let shadow = (3 - 8) * pct + 8
        return Button(action: action) {
                    animatedImage.opacity(invisible ? 0.001
                                      : unavailable ? 0.5
                                                    : 1.0)
                }
                .buttonStyle(OIMbuttonStyle())
                .disabled(disabled)
                .frame(width: oWidth, height: oHeight)
                .shadow(radius: shadow)
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
    let isDrawer: Bool              // debugging - button in the drawer
    var pct: CGFloat
    let action: () -> Void

    func imgName(_ value: UInt64?) -> String? {
        if let value {
            return value > currency.bankCoins[0] ? currency.noteName(value)
                                                 : currency.coinName(value)
        }
        return nil
    }

    var body: some View {
        let value = fund.value
        let outValue = fund.outValue
        let state = fund.state
        let isMorphing = fund.morphTicker != nil
        let flippedVal = fund.flippedVal
        // Use EmptyView, because the modifier actually ignores
        // the value passed to its body() function.
        let isFlipped: Bool = switch state {
            case .morphing: true
            case .arriving: true
            default:        false
        }
//    if fund.id >= 0 {
//        let _ = print("***Fund", fund.id, value, state, flippedVal)
//    }
        let mutating = state.mutating
        let flipTime = mutating ? 0.0001       // flip back quickly from morphed
               : fastAnimations ? 0.3
                                : 0.5
        //                    checkDisabled = true    // TODO: don't run twice
        let unavailable = availableVal < value
        if isDrawer && value == 2000 {
            if unavailable {
                let _ = print("OIMcurrencyButton❗️❗️", availableVal, value)
            }
        }
        let disabled = !canEdit || isMorphing || unavailable        // cannot edit morphing funds
        EmptyView().modifier(OIMmod(name: imgName(outValue ?? value),
                             flippedName: imgName(flippedVal),
                                flipTime: flipTime,
                               isFlipped: isFlipped,
                                flipBack: mutating,
                                disabled: disabled,
                             unavailable: unavailable,
                               invisible: state.hiding,
                                     pct: pct,
                                  action: action))
        .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))         // TODO: currency name
    }
}
