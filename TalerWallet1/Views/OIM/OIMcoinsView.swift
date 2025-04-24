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
// renders a spread of coin-stacks in 1 row
struct OIMcoinsView1: View {
    let stack: CallStack
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: UInt64
    let tappedVal: UInt64
    @Binding var flying: UInt64
    let shake: Bool
    let canEdit: Bool

    var body: some View {
        let nrOfCoins = currency.bankCoins.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfCoins, id: \.self) { index in
                let value = currency.bankCoins[index]
                let shouldFly = tappedVal == value
                let count = spread[index] + (shouldFly ? 1 : 0)
                if count > 0 {
                    OIMcoinStackV1(stack: stack.push(),
                                   value: value,
                                   count: Int(count),
                                currency: currency,
                               tappedVal: tappedVal,
                                  flying: $flying,
                                   shake: shake,
                                  canEdit: canEdit
                    ) {
                        withAnimation(Animation.easeIn1) {
                            amountVal -= value
                }   }   }
            } // ForEach
        } // HStack
    }
}
// MARK: -
// renders a spread of coin-stacks in 1 row
struct OIMcoinsView2: View {
    let stack: CallStack
                let spread: OIMdenominations
    @Binding var amountVal: UInt64
                let tappedVal: UInt64
                @Binding var flying: UInt64
    let canEdit: Bool

    @EnvironmentObject private var cash: OIMcash

    var body: some View {
        let _ = Self._printChanges()
        let currency = cash.currency
        let nrOfCoins = currency.bankCoins.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfCoins, id: \.self) { index in
                let value = currency.bankCoins[index]
                let shouldFly = tappedVal == value
                let count = spread[index] + (shouldFly ? 1 : 0)
                if count > 0 {
                    OIMcoinStackV2(stack: stack.push(),
                                            value: value,
                                            count: Int(count),
                              tappedVal: tappedVal,
                                        flying: $flying,
                                canEdit: canEdit
                    ) {
                        withAnimation(Animation.easeIn1) {
                            amountVal -= value
                }   }   }
            } // ForEach
        } // HStack
    }
}
// MARK: -
//#Preview {
//    OIMlineView()
//}
