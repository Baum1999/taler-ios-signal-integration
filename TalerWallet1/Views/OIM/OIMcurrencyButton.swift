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
    let availableVal: UInt64
    let canEdit: Bool
    var pct: CGFloat
    let action: () -> Void

    var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }

    func body(content: Content) ->  some View {
        let shadow = (3 - 8) * pct + 8
        return Group {
            let currencyImage = OIMcurrencyImage(name)
            let image = currencyImage.image
                            .resizable()
                            .scaledToFit()
            Group {
                if canEdit && availableVal >= value {
                    Button(action: action) {
                        image
                    }
                    .buttonStyle(OIMbuttonStyle())
                } else {
                    image
                        .opacity(canEdit ? 0.5 : 1.0)
                }
            }
                .frame(width: currencyImage.oWidth / 4, height: currencyImage.oHeight / 4)
                .shadow(radius: shadow)
                .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))
        }
    }
}

/// renders 1 denomination from a currency
struct OIMcurrencyButton: View {
    let value: UInt64
    let currency: OIMcurrency
    let availableVal: UInt64
    let canEdit: Bool
    var pct: CGFloat
    let action: () -> Void

    var body: some View {
        let name = value > currency.bankCoins[0] ? currency.noteName(value)
                                                 : currency.coinName(value)
        // Use EmptyView, because the modifier actually ignores
        // the value passed to its body() function.
        EmptyView().modifier(OIMmod(value: value,
                                     name: name,
                             availableVal: availableVal,
                                  canEdit: canEdit,
                                      pct: pct,
                                   action: action))
    }
}

// MARK: -
//#Preview {
//    OIMcurrencyView()
//}
