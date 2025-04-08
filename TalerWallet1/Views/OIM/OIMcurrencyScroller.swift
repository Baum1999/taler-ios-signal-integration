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
    let currency: OIMcurrency
    @Binding var availableVal: Int
    @Binding var amountVal: Int
    @Binding var tappedVal: Int
    @Binding var flying: Int
    @Binding var shake: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    func tap(value: Int, _ delay: Int = 250) {
        withAnimation(.shake1) {
            flying = 0
            tappedVal = value
        }
#if DEBUG
        let ms = debugAnimations ? 1500 : delay
#else
        let ms = delay
#endif
//        print("tapped \(value)")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
//            print("shake start")
            withAnimation(.shake1) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
//                print("shake end")
                withAnimation(.shake1) {
                    shake = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
                    withAnimation(.basic1) {
                        amountVal += value
                        tappedVal = 0
                    }
                }
            }
        }
    }
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(currency.bankNotes, id: \.self) { value in
                    OIMnoteV(value: value,
                          currency: currency,
                      availableVal: availableVal,
                           canEdit: true,
                               pct: 0.0,
                            action: { tap(value: value) }
                    )
                    .matchedGeometryEffect(id: value, in: wrapper.namespace, isSource: true)
                }
                ForEach(currency.bankCoins, id: \.self) { value in
                    OIMcoinV(value: value,
                          currency: currency,
                      availableVal: availableVal,
                           canEdit: true,
                               pct: 0.0,
                            action: { tap(value: value) }
                    )
                    .matchedGeometryEffect(id: value, in: wrapper.namespace, isSource: true)
                }
            }.padding(.trailing, UIScreen.hasNotch ? UIScreen.horzInsets : 0)   // ensure scrolling over the FaceID notch
        }
        .clipped(antialiased: true)
        .padding(.horizontal, 5)
        .ignoresSafeArea(edges: .horizontal)
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
