/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

fileprivate let horzSpacing: CGFloat = 20
fileprivate let vertSpacing: CGFloat = 10

struct OIMlineView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var amountVal: UInt64
    @Binding var tappedVal: UInt64
    let canEdit: Bool

    @EnvironmentObject private var cash: OIMcash
    @EnvironmentObject private var wrapper: NamespaceWrapper
    @AppStorage("oimTwoRows") var oimTwoRows: Bool = false

    @State private var flying: UInt64 = 0          // needed for iOS 15
    @State private var myTappedVal: UInt64 = 0

    var body: some View {
//        let _ = Self._printChanges()
#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
#endif
        let currency = cash.currency

        Group {
            if #available(iOS 16.4, *) {
                let notes = OIMlayoutView(stack: stack.push(),
                                          funds: cash.notes(),
                                      amountVal: $amountVal,
                                        canEdit: canEdit)
                let coins = OIMlayoutView(stack: stack.push(),
                                          funds: cash.coins(),
                                      amountVal: $amountVal,
                                        canEdit: canEdit)
                LayoutThatFits([HStackLayout(alignment: .center), VStackLayout()]) {
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
            } else { // iOS 15
                let result = currency.notesCoins(amountVal)
                // Text("notes: \(result.0), coins: \(result.1)")
                let notes = OIMnotesView1(stack: stack.push(),
                                         spread: result.0,
                                       currency: currency,
                                      amountVal: $amountVal,
                                      tappedVal: myTappedVal,
                                         flying: $flying,
                                        canEdit: canEdit
                            ).id("notes")
                             .matchedGeometryEffect(id: "notes", in: wrapper.namespace)
#if DEBUG
                             .border(blue)
#endif
                let coins = OIMcoinsView1(stack: stack.push(),
                                         spread: result.1,
                                       currency: currency,
                                      amountVal: $amountVal,
                                      tappedVal: myTappedVal,
                                         flying: $flying,
                                        canEdit: canEdit
                            ).id("coins")
                             .matchedGeometryEffect(id: "coins", in: wrapper.namespace)
#if DEBUG
                             .border(red)
#endif

                ScrollView(.horizontal) {
                    if oimTwoRows {
                        VStack(spacing: vertSpacing) {
                            notes
                            coins
                        }
#if DEBUG
                            .padding(1)
                            .border(green)
#endif
                    } else {
                        HStack(alignment: .center, spacing: horzSpacing) {
                            notes
                            coins
                        }
#if DEBUG
                            .padding(1)
                            .border(green)
#endif
                    }
                }
#if DEBUG
                    .padding(1)
                    .border(orange)
#endif
                    .clipped()
            } // iOS 15
        }
        .onChange(of: tappedVal) { newVal in
            if newVal > 0 {
                symLog.log(">>tapped \(newVal)")
                tappedVal = 0

                DispatchQueue.main.async {                      // next layout cycle
                    withAnimation(.move1) {
                        if #available(iOS 16.0, *) {
                            symLog.log(">>addCash \(newVal)")
                            cash.addCash(value: newVal)
                            amountVal += newVal                 // update directly
                        } else {
                            symLog.log("\n>>start flying \(newVal) \(flying)")
                            myTappedVal = newVal
                        }
                    }
                    if #unavailable(iOS 16.0) {
                        symLog.log("\n>>reset flying \(newVal) \(flying)")
                        flying = 0  // remove immediately after it flew in, but outside of the animation block
                        DispatchQueue.main.asyncAfter(deadline: .now() + cash.delay) {
                            symLog.log("\n>>dissolve \(newVal) \(flying)")
                            withAnimation(.basic1) {
                                amountVal += newVal             // update after value flew in
                                myTappedVal = 0
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: -
//#Preview {
//    OIMlineView()
//}
