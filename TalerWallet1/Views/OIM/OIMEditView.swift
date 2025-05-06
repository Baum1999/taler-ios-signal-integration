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
@available(iOS 16.4, *)
struct OIMEditView: View {
    let stack: CallStack
    let cash: OIMcash
    @Binding var amount: Amount
    let available: Amount
    let useAvailable : Bool         // if false then we're requesting money and don't use available
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var amountVal: UInt64 = 0
    @State private var sending = false              // user tapped on Send
    @State private var availableVal: UInt64 = 0
    @State private var availRest: Amount
    @State private var tappedVal: UInt64 = 0

    init(stack: CallStack, cash: OIMcash,
         amount: Binding<Amount>,
         available: Amount,
         useAvailable : Bool,
         fwdButtonTapped: Binding<Bool>
    ) {
        self.stack = stack
        self.cash = cash
        self._amount = amount
        self.available = available
        self.useAvailable = useAvailable
        self._fwdButtonTapped = fwdButtonTapped
        self._availRest = State(wrappedValue: { available }())
    }


    // available minus amountVal - what's still available from the balance when amount is on the table
    var isAvailable: UInt64 {
        if useAvailable {
            let have = available.centValue
            let want = amount.centValue
            if have > want {
                return have - want
            }
            return 0
        }
        return 999_999_999
    }

    func sendAction() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
//          withAnimation(.basic1.delay(delay + 0.5)) {
            withAnimation(.basic1) {
                sending = true                // hide scroller
            }
//          DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) {       // cash.delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    fwdButtonTapped = true          // ==> go to purpose/goal
                }
            }
//        }
    }

    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print(">>> OIMEditView", available, amount, stack.peek()?.file)

        let noteBase = cash.currency.noteBase
        let isSierra = noteBase == "SLE"
        OIMnavBack(stack: stack.push(),
            currencyName: noteBase,
                 isFinal: false,
                  isGoal: true,
                isSierra: isSierra,
               isSending: sending,
                  amount: $amount,
                  action: sendAction
        ) {
            ZStack(alignment: .top) {
                VStack {
//                    OIMtitleView(cash: cash, amount: availRest, isSending: true, secondAmount: amount)
                    OIMtitleView(cash: cash, amount: available, isSending: true, secondAmount: amount)
                    Spacer()
                    OIMlineView(stack: stack.push(),
                                 cash: cash,
                            amountVal: $amountVal,
                            tappedVal: $tappedVal,          // <- user tapped a val in the scroller
                              canEdit: true)
                        .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace, isSource: true)
                        .zIndex(1)  // make notes fly from topZ
                        .scaleEffect(sending ? 0.6 : 1.0)
                        .onChange(of: amountVal) { newVal in
                            let currencyStr = amount.currencyStr
                            amount = Amount(currency: currencyStr, cent: UInt64(newVal))
                            availableVal = isAvailable
                            availRest = Amount(currency: currencyStr, cent: UInt64(availableVal))
                        }
                    if !sending {       // need space for currency scroller
                        Spacer()
                        Spacer()
                    }
                }
                VStack {
                    Spacer()
                    let maxAvailable = useAvailable ? cash.max(available: available.centValue) : 0
                    OIMcurrencyScroller(stack: stack.push(),
                                         cash: cash,
                                 availableVal: $availableVal,           // ==> available - amount
                                    tappedVal: $tappedVal,
                               scrollPosition: maxAvailable,            // max note or coin (available)
                                      canEdit: true)
                        .zIndex(2)  // make notes fly from topZ
                        .clipped(antialiased: true)
                        .padding(.horizontal, 5)
                        .ignoresSafeArea(edges: .horizontal)
                        .opacity(sending ? 0.01 : 1.0)
                }
//              .border(.red)
            } // ZStack
        }
        .task {
            amountVal = amount.centValue
            availableVal = isAvailable
//            print("OIMEditView.task", availableVal, amountVal)
            cash.update(amountVal)
        }
        .onAppear {
//            print("OIMEditView.onAppear", availableVal, amountVal)
            withAnimation(.basic1) {
                sending = false                              // move back up when coming back
            }
        }
    }
}
