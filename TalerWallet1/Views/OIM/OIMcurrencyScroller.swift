/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// renders all banknotes and coins in 1 horizontal scrollview
struct OIMcurrencyScroller: View {
    let stack: CallStack
    @Binding var availableVal: UInt64
    @Binding var tappedVal: UInt64

    @EnvironmentObject private var cash: OIMcash
    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        let currency = cash.currency
        ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(currency.bankNotes, id: \.self) { value in
                    let fund = OIMfund(id: -Int(value), state: .idle, value: value, flippedVal: nil)
                    let sourceID = -Int(value)
                    OIMcurrencyButton(stack: stack.push(),
                                       fund: fund,
                                   currency: currency,
                               availableVal: availableVal,
                                    canEdit: true,
                                        pct: 0.9,
                                     action: { tappedVal = value }
                    )
                    .matchedGeometryEffect(id: String(sourceID), in: wrapper.namespace, isSource: true)
                }
                ForEach(currency.bankCoins, id: \.self) { value in
                    let fund = OIMfund(id: -Int(value), state: .idle, value: value, flippedVal: nil)
                    let sourceID = -Int(value)
                    OIMcurrencyButton(stack: stack.push(),
                                       fund: fund,
                                   currency: currency,
                               availableVal: availableVal,
                                    canEdit: true,
                                        pct: 0.9,
                                     action: { tappedVal = value }
                    )
                    .matchedGeometryEffect(id: String(sourceID), in: wrapper.namespace, isSource: true)
                }
            }.padding(.trailing, UIScreen.hasNotch ? UIScreen.horzInsets : 0)   // ensure scrolling over the FaceID notch
        }
        .viewExtractor { view in
            if let scrollView = view as? UIScrollView {
                if #available(iOS 17.4, *) {
                    scrollView.bouncesVertically = false
                } else {    // Fallback on earlier versions
                    scrollView.bounces = false
                }
            }
        }
    }
}
// MARK: -
//#Preview {
//    OIMcurrencyScroller()
//}
