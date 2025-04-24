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

@available(iOS 16.4, *)
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
        .onChange(of: tappedVal) { newVal in
            if newVal > 0 {
                symLog.log(">>tapped \(newVal)")
                tappedVal = 0

                DispatchQueue.main.async {                      // next layout cycle
                    withAnimation(.move1) {
                        symLog.log(">>addCash \(newVal)")
                        cash.addCash(value: newVal)
                        amountVal += newVal                     // update directly
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
