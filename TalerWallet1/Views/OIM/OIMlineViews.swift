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
    let tappedVal: Int
    @Binding var flying: Int
    let shake: Bool
    let canEdit: Bool

    var body: some View {
//        let _ = Self._printChanges()
        let nrOfNotes = currency.bankNotes.count - 1
        HStack(alignment: .top, spacing: 10) {
            ForEach(0...nrOfNotes, id: \.self) { index in
                let value = currency.bankNotes[index]
                let shouldFly = tappedVal == value
                let count = spread[index] + (shouldFly ? 1 : 0)
                if count > 0 {
                    OIMnoteStackV(value: value,
                                  count: count,
                               currency: currency,
                              tappedVal: tappedVal,
                                 flying: $flying,
                                  shake: shake,
                                canEdit: canEdit
                    ) {
                        withAnimation(.basic1) {
                            amountVal -= value     // remove on button press
                }   }   }
            } // ForEach
        } // HStack
    }
}

// MARK: -
// renders a spread of coin-stacks in 1 row
struct OIMcoinsView1: View {
    let spread: OIMdenominations
    let currency: OIMcurrency
    @Binding var amountVal: Int
    let tappedVal: Int
    @Binding var flying: Int
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
                    OIMcoinStackV(value: value,
                                  count: count,
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
fileprivate let horzSpacing: CGFloat = 20
fileprivate let vertSpacing: CGFloat = 10

struct OIMlineView: View {
    let currency: OIMcurrency
    @Binding var amountVal: Int
    let tappedVal: Int
    @Binding var flying: Int
    let shake: Bool
    let canEdit: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper
    @AppStorage("oimTwoRows") var oimTwoRows: Bool = false

    var body: some View {
//        let _ = Self._printChanges()
#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
#endif
        let result = currency.notesCoins(amountVal)
        // Text("notes: \(result.0), coins: \(result.1)")
        let notes = OIMnotesView1(spread: result.0,
                                currency: currency,
                               amountVal: $amountVal,
                               tappedVal: tappedVal,
                                  flying: $flying,
                                   shake: shake,
                                 canEdit: canEdit
                    ).id("notes")
                     .matchedGeometryEffect(id: "notes", in: wrapper.namespace)
#if DEBUG
            .border(blue)
#endif
        let coins = OIMcoinsView1(spread: result.1,
                                currency: currency,
                               amountVal: $amountVal,
                               tappedVal: tappedVal,
                                  flying: $flying,
                                   shake: shake,
                                 canEdit: canEdit
                    ).id("coins")
                     .matchedGeometryEffect(id: "coins", in: wrapper.namespace)
#if DEBUG
            .border(red)
#endif

        let oneLine = HStack(spacing: horzSpacing) {
            notes
            coins
        }
        let twoLines = VStack(spacing: vertSpacing) {
            notes
            coins
        }

        let scrollView = ScrollView(.horizontal) {
            if oimTwoRows {
                twoLines
#if DEBUG
                    .padding(1)
                    .border(green)
#endif
            } else {
                oneLine
#if DEBUG
                    .padding(1)
                    .border(green)
#endif
            }
        }
        if #available(iOS 16.0, *) {
            Group {
                if false {
                    scrollView
#if DEBUG
                    .padding(1)
                    .border(orange)
#endif
                    .clipped()
                    .scrollIndicators(.visible)
                    .viewExtractor { view in
                        if let scrollView = view as? UIScrollView {
                            if #available(iOS 17.4, *) {
                                scrollView.bouncesVertically = false
                            } else {    // Fallback on earlier versions
                                scrollView.bounces = false
                            }
                        }
                    }
                } else {
                    LayoutThatFits([HStackLayout(alignment: .top), VStackLayout()]) {
                        notes
#if DEBUG
                            .padding(1)
                            .border(green)
#endif
                        coins
                    }
#if DEBUG
                    .padding(1)
                    .border(orange)
#endif
                }
            }
        } else {
            // Fallback on earlier versions
            scrollView
        }
    }
}

// MARK: -
//#Preview {
//    OIMlineView()
//}
