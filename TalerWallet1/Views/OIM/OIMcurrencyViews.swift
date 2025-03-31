/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct OIMbuttonStyle: ButtonStyle {

    public func makeBody(configuration: OIMbuttonStyle.Configuration) -> some View {
        configuration.label
//            .foregroundColor(.white)
//            .padding(15)
//            .background(RoundedRectangle(cornerRadius: 5).fill(color))
//            .compositingGroup()
//            .shadow(color: .black, radius: 3)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

/// renders 1 banknote from a currency with size/4
struct OIMnoteV: View {
    let value: Int
    let currency: OIMcurrency
    let availableVal: Int
    let canEdit: Bool
    var pct: CGFloat
    let action: () -> Void

    var body: some View {
#if PRINT_CHANGES || true
        let _ = Self._printChanges()
#endif
        // Use EmptyView, because the modifier actually ignores
        // the value passed to its body() function.
        EmptyView().modifier(OIMmod(value: value,
                                 currency: currency,
                             availableVal: availableVal,
                                  canEdit: canEdit,
                                      pct: pct,
                                   action: action))
    }
}

struct OIMmod: AnimatableModifier {
    let value: Int
    let currency: OIMcurrency
    let availableVal: Int
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
            if let name = currency.noteName(value) {
                let image = Image(name)
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
                .frame(width: currency.noteWidth / 4, height: currency.noteHeight / 4)
                .shadow(radius: shadow)
                .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))
            } else {
                EmptyView()
            }
        }
    }
}

/// renders 1 coin from a currency with size/4
struct OIMcoinV: View {
    let value: Int
    let currency: OIMcurrency
    let availableVal: Int
    let canEdit: Bool
    let action: () -> Void

    var body: some View {
        if let name = currency.coinName(value), let size = currency.coinSize(value) {
            let image = Image(name)
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
                .frame(width: size / 4, height: size / 4)
                .accessibilityLabel(Text("\(value)", comment: "VoiceOver"))
        } else {
            EmptyView()
        }
    }
}

/// renders 1 denomination from a currency
struct OIMsingleV: View {
    let value: Int
    let currency: OIMcurrency
    let availableVal: Int
    let canEdit: Bool
    var pct: CGFloat
    let action: () -> Void

    var body: some View {
        if value > currency.bankCoins[0] {
            OIMnoteV(value: value, currency: currency, availableVal: availableVal, canEdit: canEdit, pct: pct, action: action)
        } else {
            OIMcoinV(value: value, currency: currency, availableVal: availableVal, canEdit: canEdit, action: action)
        }
    }
}

// MARK: -
// renders a stack of (identical) banknotes with offset 20
struct OIMnoteStackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency
    let namespace: Namespace.ID
    let tappedVal: Int
    @Binding var isFlyingToDeck: Bool
    let shake: Bool
    let canEdit: Bool
    let action: () -> Void

    var body: some View {
#if PRINT_CHANGES || true
        let _ = Self._printChanges()
#endif
        let maxIndex = count - 1
        ZStack {
            ForEach(0...maxIndex, id: \.self) { index in
                let match = tappedVal == value && index == maxIndex
                let id = match && !isFlyingToDeck ? value : -value
                let xOffset = CGFloat(10 * index)
                let yOffset = CGFloat(20 * index)
                let shakeOffset: CGSize = shake ? .random(width: 10...40, height: 5...10)
                                                : .zero
                let _ = print("id \(id), flying \(isFlyingToDeck), shaking \(shakeOffset)")
                OIMnoteV(value: value,
                      currency: currency,
                  availableVal: value,
                       canEdit: canEdit,
                           pct: match ? 0.0 : 1.0,
                        action: action)
                    .offset(x: xOffset + shakeOffset.width, y: yOffset - shakeOffset.height)
                    .matchedGeometryEffect(id: id, in: namespace, isSource: false)
                    .onAppear {
                        print("start flying \(id), shaking \(shakeOffset)")
                        withAnimation(.fly1) {
                            isFlyingToDeck = true
                        }
                    }
            }
        }
        .padding(.trailing, CGFloat(10 * maxIndex))
        .padding(.bottom, CGFloat(20 * maxIndex))
    }
}

// renders a stack of (identical) coins with offset size/16
struct OIMcoinStackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency
    let canEdit: Bool
    let action: () -> Void

    var body: some View {
        let number = count - 1
        if let size = currency.coinSize(value) {
            let offset = size / 16
            ZStack {
                ForEach(0...number, id: \.self) { index in
                    OIMcoinV(value: value, currency: currency, availableVal: value, canEdit: canEdit, action: action)
                        .offset(x: offset * CGFloat(index), y: offset * CGFloat(index))
                }
            }
            .padding(.trailing, offset * CGFloat(number))
            .padding(.bottom, offset * CGFloat(number))
        }
    }
}

// renders a stack of 1 denomination
//struct OIMstackV: View {
//    let value: Int
//    let count: Int
//    let currency: OIMcurrency
//    let canEdit: Bool
//    var pct: CGFloat
//    let action: () -> Void
//
//    var body: some View {
//        if value > currency.bankCoins[0] {
//            OIMnoteStackV(value: value, count: count, currency: currency, canEdit: canEdit, pct: pct, action: action)
//        } else {
//            OIMcoinStackV(value: value, count: count, currency: currency, canEdit: canEdit, pct: pct, action: action)
//        }
//    }
//}
// MARK: -
//#Preview {
//    OIMstackV()
//}
