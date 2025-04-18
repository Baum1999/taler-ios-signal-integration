/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
//import taler_swift

// These views are for iOS 15 only - remove once iOS 16 is the Minimum Deployment
// MARK: -
// renders a stack of (identical) banknotes with offset 10,20
struct OIMnoteStackV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let value: UInt64
    let count: Int
    let currency: OIMcurrency
    let tappedVal: UInt64
    @Binding var flying: UInt64
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
                let targetID = isTarget ? String(-Int(value))
                                        : String(value) + "+" + String(index)
                let xOffset = CGFloat(10 * index)
                let yOffset = CGFloat(20 * index)
                let _ = print("targetID \(targetID), flying \(flying)")
                let fund = OIMfund(id: Int(value), state: .idle, value: value, flippedVal: nil)
                OIMcurrencyButton(stack: stack.push(),
//                                  value: value,
                fund: fund,
                             currency: currency,
                         availableVal: value,
                              canEdit: canEdit,
//                            isFlipped: false,      // TODO: Flip coin
                                  pct: match ? 0.0 : 1.0,
                               action: action)
                    .offset(x: xOffset, y: yOffset)
                    .matchedGeometryEffect(id: targetID, in: wrapper.namespace, isSource: false)
                    .onAppear {
                        print("start flying \(targetID)")
                        withAnimation(.move1) {
                            flying = value  // start flying
                        }
                    }
                    .zIndex(5)
            }
        }
        .padding(.trailing, CGFloat(10 * maxIndex))
        .padding(.bottom, CGFloat(20 * maxIndex))
    }
}
// MARK: -
// renders a stack of (identical) coins with offset size/16
struct OIMcoinStackV: View {
    let stack: CallStack
    let value: UInt64
    let count: Int
    let currency: OIMcurrency
    let tappedVal: UInt64
    @Binding var flying: UInt64
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
                    let targetID = isTarget ? String(-Int(value))
                                            : String(value) + "+" + String(index)
                    let yOffset = offset * CGFloat(index)
                    let xOffset = yOffset / 2
                    let _ = print("targetID \(targetID), flying \(flying)")
                    let fund = OIMfund(id: Int(value), state: .idle, value: value, flippedVal: nil)    // TODO: Flip coin
                    OIMcurrencyButton(stack: stack.push(),
//                                    value: value,
                                       fund: fund,
                                   currency: currency,
                               availableVal: value,
                                    canEdit: canEdit,
//                                isFlipped: false,      // TODO: Flip coin
                                        pct: match ? 0.0 : 1.0,
                                     action: action)
                    .offset(x: xOffset, y: yOffset)
                    .matchedGeometryEffect(id: targetID, in: wrapper.namespace, isSource: false)
                    .onAppear {
                        print("start flying \(targetID)")
                        withAnimation(.move1) {
                            flying = value  // start flying
                        }
                    }
                    .zIndex(5)
                }
            }
            .padding(.trailing, offset * CGFloat(maxIndex))
            .padding(.bottom, offset * CGFloat(maxIndex))
        }
    }
}
// MARK: -
// renders a spread of banknote-stacks in 1 row
struct OIMnotesView1: View {
    let stack: CallStack
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: UInt64
    let tappedVal: UInt64
    @Binding var flying: UInt64
    let canEdit: Bool

    var body: some View {
//        let _ = Self._printChanges()
        let nrOfNotes = currency.bankNotes.count - 1
        HStack(alignment: .center, spacing: 10) {
            ForEach(0...nrOfNotes, id: \.self) { index in
                let value = currency.bankNotes[index]
                let shouldFly = tappedVal == value
                let count = spread[index] + (shouldFly ? 1 : 0)
                if count > 0 {
                    OIMnoteStackV(stack: stack.push(),
                                  value: value,
                                  count: Int(count),
                               currency: currency,
                              tappedVal: tappedVal,
                                 flying: $flying,
                                canEdit: canEdit
                    ) {
                        withAnimation(.easeOut1) {
                            amountVal -= value     // remove on button press
                        }   }   }
            } // ForEach
        } // HStack
    }
}
// MARK: -
// renders a spread of coin-stacks in 1 row
struct OIMcoinsView1: View {
    let stack: CallStack
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: UInt64
    let tappedVal: UInt64
    @Binding var flying: UInt64
    let canEdit: Bool

    var body: some View {
        let nrOfCoins = currency.bankCoins.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfCoins, id: \.self) { index in
                let value = currency.bankCoins[index]
                let shouldFly = tappedVal == value
                let count = spread[index] + (shouldFly ? 1 : 0)
                if count > 0 {
                    OIMcoinStackV(stack: stack.push(),
                                  value: value,
                                  count: Int(count),
                                  currency: currency,
                                  tappedVal: tappedVal,
                                  flying: $flying,
                                  canEdit: canEdit
                    ) {
                        withAnimation(.easeIn1) {
                            amountVal -= value
                        }   }   }
            } // ForEach
        } // HStack
    }
}
