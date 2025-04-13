/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift


// MARK: -
// renders a stack of (identical) banknotes with offset 10,20
struct OIMnoteStackV: View {
    let stack: CallStack
    let value: UInt64
    let count: Int
    let currency: OIMcurrency
    let tappedVal: UInt64
    @Binding var flying: UInt64
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
                let matchNotFlying = match && !isFlying
                let isTarget = matchNotFlying // && isTop
                let targetId = isTarget ? String(value)
                                        : String(value) + "+" + String(index)
                let xOffset = CGFloat(10 * index)
                let yOffset = CGFloat(20 * index)
                let shakeOffset: CGFloat = shake && !match ? .random(in: 10...25)
                                                           : .zero
                let direction = value < tappedVal
//                let _ = print("id \(id), flying \(flying), shaking \(shakeOffset)")
                OIMcurrencyButton(value: value,
                             currency: currency,
                         availableVal: value,
                              canEdit: canEdit,
                                  pct: match ? 0.0 : 1.0,
                               action: action)
                    .offset(x: xOffset + (direction ? shakeOffset : -shakeOffset),
                            y: yOffset)
                    .matchedGeometryEffect(id: targetId, in: wrapper.namespace, isSource: false)
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
    let stack: CallStack
    let value: UInt64
    let count: Int
    let currency: OIMcurrency
    let tappedVal: UInt64
    @Binding var flying: UInt64
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
                    let matchNotFlying = match && !isFlying
                    let isTarget = matchNotFlying // && isTop
                    let targetId = isTarget ? String(value)
                                            : String(value) + "+" + String(index)
                    let yOffset = offset * CGFloat(index)
                    let xOffset = yOffset / 2
                    let shakeOffset: CGFloat = shake && !match ? .random(in: 5...10)
                                                               : .zero
                    let direction = value < tappedVal
                    OIMcurrencyButton(value: value,
                                 currency: currency,
                             availableVal: value,
                                  canEdit: canEdit,
                                      pct: match ? 0.0 : 1.0,
                                   action: action)
                        .offset(x: xOffset + (direction ? shakeOffset : -shakeOffset),
                                y: yOffset)
                        .matchedGeometryEffect(id: targetId, in: wrapper.namespace, isSource: false)
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
