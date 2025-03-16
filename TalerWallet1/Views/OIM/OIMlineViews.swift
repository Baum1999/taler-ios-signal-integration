/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// renders a spread of banknote-stacks in 1 row
struct OIMnotesView1: View {
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: Int
    let canEdit: Bool

    var body: some View {
        let nrOfNotes = currency.bankNotes.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfNotes, id: \.self) { index in
                let count = spread[index]
                if count > 0 {
                    let value = currency.bankNotes[index]
                    let noteStack = OIMnoteStackV(value: value, count: count, currency: currency)
                    if canEdit {
                        noteStack.onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amountVal -= value
                            }
                        }
                    } else { noteStack }
                }
            }
        }
    }
}

// MARK: -
// renders a spread of coin-stacks in 1 row
struct OIMcoinsView1: View {
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: Int
    let canEdit: Bool

    var body: some View {
        let nrOfCoins = currency.bankCoins.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfCoins, id: \.self) { index in
                let count = spread[index]
                if count > 0 {
                    let value = currency.bankCoins[index]
                    let coinStack = OIMcoinStackV(value: value, count: count, currency: currency)
                    if canEdit {
                        coinStack.onTapGesture {
                            withAnimation(Animation.easeIn(duration: 0.25)) {
                                amountVal -= value
                            }
                        }
                    } else { coinStack }
                }
            }
        }
    }
}

// MARK: -

struct OIMlineView: View {
    let currency: OIMcurrency
    @Binding var amountVal: Int
    let canEdit: Bool
    let oneLine: Bool

    var body: some View {
        let result = currency.notesCoins(amountVal)
        // Text("notes: \(result.0), coins: \(result.1)")
        let notes = OIMnotesView1(spread: result.0, currency: currency, amountVal: $amountVal, canEdit: canEdit)
        let coins = OIMcoinsView1(spread: result.1, currency: currency, amountVal: $amountVal, canEdit: canEdit)
        if oneLine {
            HStack {
                notes.padding(.trailing, 20)
                coins
            }
        } else {
            VStack {
                notes
                coins
            }
        }
    }
}

//#Preview {
//    OIMView()
//}
