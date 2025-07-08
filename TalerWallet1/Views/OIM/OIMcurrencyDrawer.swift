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
struct OIMcurrencyDrawer: View {
    let stack: CallStack
    let cash: OIMcash
    @Binding var availableVal: UInt64
    @Binding var tappedVal: UInt64
    let scrollPosition: UInt64
    let canEdit: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let currency = cash.currency
        let taskID = currency.noteBase + String(scrollPosition)
        ScrollViewReader { proxy in
          ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(currency.bankNotes, id: \.self) { value in
                    let sourceID = -Int(value)
                    let fund = OIMfund(id: sourceID, value: value,
                            currencyIndex: cash.currencyIndex)
                    OIMcurrencyButton(stack: stack.push(),
                                       fund: fund,
                                   currency: currency,
                               availableVal: availableVal,
                                    canEdit: canEdit,
                                   isDrawer: true,
                                        pct: 0.9,                       // hover a bit above the desk
                                     action: { tappedVal = value }
                    )
                    .id(currency.noteBase + String(sourceID))
                    .matchedGeometryEffect(id: String(sourceID), in: wrapper.namespace, isSource: true)
                }
                ForEach(currency.bankCoins, id: \.self) { value in
                    let sourceID = -Int(value)
                    let fund = OIMfund(id: sourceID, value: value,
                            currencyIndex: cash.currencyIndex)
                    OIMcurrencyButton(stack: stack.push(),
                                       fund: fund,
                                   currency: currency,
                               availableVal: availableVal,
                                    canEdit: canEdit,
                                   isDrawer: true,
                                        pct: 0.9,
                                     action: { tappedVal = value }
                    )
                    .id(currency.noteBase + String(sourceID))
                    .matchedGeometryEffect(id: String(sourceID), in: wrapper.namespace, isSource: true)
                }
            }.padding(.trailing, UIScreen.hasNotch ? UIScreen.horzInsets : 0)   // ensure scrolling over the FaceID notch
        }
          .onAppear {
              if scrollPosition > 0 {
//                  print(">>> OIMcurrencyScroller.onAppear scrolling to", scrollPosition, canEdit)
                  proxy.scrollTo(currency.noteBase + String(-Int(scrollPosition)), anchor: .leading)
//                  DispatchQueue.main.async {
//                      print(">>> OIMcurrencyScroller.onAppear scrolling AGAIN to", scrollPosition, canEdit)
//                      proxy.scrollTo(-Int(scrollPosition), anchor: .leading)
//                  }
                  debugTick += 1
              } else {      // should only happen if available is zero
                  print("❗️❗️ OIMcurrencyScroller.onAppear scrolling to", scrollPosition, canEdit) // , stack.peek()?.file)
              }
          }
          .task(id: taskID) {
              if !canEdit && scrollPosition > 0 {
                  debugTick += 1
//                  print(">>❗️ OIMcurrencyScroller.task", cash.currency.noteBase, availableVal, scrollPosition)
                  proxy.scrollTo(currency.noteBase + String(-Int(scrollPosition)), anchor: .leading)
                  debugTick += 1
              }
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
}
