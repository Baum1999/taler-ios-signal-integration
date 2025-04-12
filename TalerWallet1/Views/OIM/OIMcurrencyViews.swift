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
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}

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

struct OIMmod: AnimatableModifier {
    let value: Int
    let name: String?
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
struct OIMcurrencyView: View {
    let value: Int
    let currency: OIMcurrency
    let availableVal: Int
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
// renders a stack of (identical) banknotes with offset 10,20
struct OIMnoteStackV: View {
    let value: Int
    let count: Int
    let currency: OIMcurrency
    let tappedVal: Int
    @Binding var flying: Int
    let shake: Bool
    let canEdit: Bool
    let action: () -> Void

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
//        let _ = Self._printChanges()
        let maxIndex = count - 1
        ZStack {
            ForEach(0...maxIndex, id: \.self) { index in
                let match = tappedVal == value && index == maxIndex
                let isFlying = flying > 0
                let id = match && !isFlying ? value : -value
                let xOffset = CGFloat(10 * index)
                let yOffset = CGFloat(20 * index)
                let shakeOffset: CGFloat = shake && !match ? .random(in: 10...25)
                                                           : .zero
                let direction = value < tappedVal
//                let _ = print("id \(id), flying \(flying), shaking \(shakeOffset)")
                OIMcurrencyView(value: value,
                             currency: currency,
                         availableVal: value,
                              canEdit: canEdit,
                                  pct: match ? 0.0 : 1.0,
                               action: action)
                    .offset(x: xOffset + (direction ? shakeOffset : -shakeOffset),
                            y: yOffset)
                    .matchedGeometryEffect(id: id, in: wrapper.namespace, isSource: false)
                    .onAppear {
//                        print("start flying \(id), shaking \(shakeOffset)")
                        withAnimation(.fly1) {
                            flying = value  // start flying
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
    let tappedVal: Int
    @Binding var flying: Int
    let shake: Bool
    let canEdit: Bool
    let action: () -> Void

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        let maxIndex = count - 1
        if let size = currency.coinSize(value) {
            let offset = size / 16
            ZStack {
                ForEach(0...maxIndex, id: \.self) { index in
                    let match = tappedVal == value && index == maxIndex
                    let isFlying = flying > 0
                    let id = match && !isFlying ? value : -value
                    let yOffset = offset * CGFloat(index)
                    let xOffset = yOffset / 2
                    let shakeOffset: CGFloat = shake && !match ? .random(in: 5...10)
                                                               : .zero
                    let direction = value < tappedVal
                    OIMcurrencyView(value: value,
                                 currency: currency,
                             availableVal: value,
                                  canEdit: canEdit,
                                      pct: match ? 0.0 : 1.0,
                                   action: action)
                        .offset(x: xOffset + (direction ? shakeOffset : -shakeOffset),
                                y: yOffset)
                        .matchedGeometryEffect(id: id, in: wrapper.namespace, isSource: false)
                        .onAppear {
//                        print("start flying \(id), shaking \(shakeOffset)")
                            withAnimation(.fly1) {
                                flying = value  // start flying
                            }
                        }
                }
            }
            .padding(.trailing, offset * CGFloat(maxIndex))
            .padding(.bottom, offset * CGFloat(maxIndex))
        }
    }
}
// MARK: -
//#Preview {
//    OIMstackV()
//}
