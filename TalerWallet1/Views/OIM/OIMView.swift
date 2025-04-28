/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate func intValue(_ amount: Amount?) -> UInt64 {
    if let amount {
        if !amount.isZero {
            let int = amount.integer * 100              // TODO: currency specs instead of 100
            let frac = amount.fraction / 1_000_000      // drop 6 zeroes
            return int + UInt64(frac)
        }
    }
    return 0
}
// MARK: -
struct OIMnavBack<Content: View>: View {
    let stack: CallStack
    let currencyName: String
    @Binding var amount: Amount
    @Binding var fwdButtonTapped: Bool
    var content: () -> Content

    @Environment(\.dismiss) var dismiss     // pop back once

    var body: some View {
        OIMbackground() {
            ZStack(alignment: .top) {
                content()
                VStack {
                    HStack {
                        OIMbalanceButton(isOpen: true, tint: false) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismiss()
                            }
                        }
                        .frame(width: 66, height: 66)
                        Spacer()
                        OIMsendButton(isGoal: true, enabled: !amount.isZero) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                fwdButtonTapped = true
                            }
                        }
                        .frame(width: 66, height: 66)
                    }
                }
#if DEBUG
                .border(.blue)
#endif
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMView: View {
    let stack: CallStack
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var selectedBalance: Balance?      // return user's choice
    @Binding var selectedIndex: Int?
    @Binding var qrButtonTapped: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var wrapper: NamespaceWrapper

    @StateObject private var cash = OIMcash()
    @State private var availableVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0
    @State private var sending = false
    @State private var available: Amount? = nil
    @State private var isOpen: Int? = nil

    func sendAction() {
//        let delay =
            cash.moveDown()                                 // cash animates itself
//        withAnimation(.basic1.delay(delay + 0.5)) {
        withAnimation(.basic1.delay(0.6)) {
            sending = true                                  // blends in the missing denominations
        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) {       // cash.delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let actionType = ActionType(animationDisabled: true)
            let userinfo = [NOTIFICATIONANIMATION: actionType]
            // will trigger NavigationLink
            NotificationCenter.default.post(name: .SendAction,          // switch to OIMEditView
                                          object: nil,
                                        userInfo: userinfo)
        }
    }

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let actions = HStack(alignment: .top) {
            QRButton(hideTitle: true) {
//                var transaction = Transaction()
//                transaction.disablesAnimations = true
//                withTransaction(transaction) {
                    qrButtonTapped = true
//                }
            }
                .opacity(sending ? 0.01 : 1.0)
                .frame(width: 66, height: 66)
                .matchedGeometryEffect(id: "OIMback", in: wrapper.namespace,isSource: true)
            Spacer()
            let enabled = if let available {
                !available.isZero
            } else { false }
            OIMsendButton(isGoal: false, enabled: enabled, action: sendAction)
                .frame(width: 66, height: 66)
        }

        let numberView = HStack {
            OIMbalanceButton(isOpen: true, tint: false) {}
                .frame(width: 66, height: 66)
                .disabled(true)
                .opacity(0.01)
                .matchedGeometryEffect(id: "OIMnumber", in: wrapper.namespace,isSource: true)

            OIMamountV(amount: available, currencyName: cash.currency.noteBase)
        }

        let maxAvailable = cash.max(available: intValue(available))
        let _ = print("maxAvailable", maxAvailable)

        OIMbackground() {
            ZStack(alignment: .top) {
                actions
                numberView
                VStack {
                    Spacer()
                    HStack(spacing: 30) {
//                        ForEach(controller.balances, id: \.self) { balance in
//                            OIMbalanceButton(isOpen: selectedBalance == balance) {

                        let balance = controller.balances[0]
                        ForEach(0...1, id: \.self) { index in
                            let itsMe = isOpen == index
                            let isClosed = isOpen == nil
                            let size = isClosed ? 120.0 : 66.0
                            OIMbalanceButton(isOpen: itsMe, tint: index > 0) {
                                withAnimation(.basic1) {
                                    if itsMe {
                                        isOpen = nil
                                        selectedBalance = nil
                                        selectedIndex = nil
                                        available = nil
                                    } else {
                                        isOpen = index
                                        selectedIndex = index
                                        cash.currency = index == 0 ? OIMeuros : OIMleones
                                        selectedBalance = balance
                                        available = balance.available
                                    }
                                }
                            }
                            .frame(width: size, height: size)
                            .zIndex(itsMe ? 3 : 0)
                            .opacity((isClosed || itsMe) ? 1.0 : 0.01)
                            .matchedGeometryEffect(id: itsMe ? (sending ? "OIMback" : "OIMnumber")
                                                             : String(index),
                                                   in: wrapper.namespace,isSource: false)
                            .frame(width: size, height: size)
                        }
                    }
                    Spacer()
                }
                VStack {
                    Spacer()
                    OIMlineView(stack: stack.push(),
                                 cash: cash,
                            amountVal: $availableVal,
                            tappedVal: $tappedVal,
                              canEdit: false)
                    .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace,isSource: true)
                    .zIndex(2)  // make notes fly from topZ
                    Spacer()
                }
#if DEBUG
//                .border(.red)
#endif
                VStack {
                    Spacer()
                    OIMcurrencyScroller(stack: stack.push(),
                                         cash: cash,
                                 availableVal: $availableVal,
                                    tappedVal: $tappedVal,
                               scrollPosition: maxAvailable,
                                      canEdit: false)
                    .clipped(antialiased: true)
                    .padding(.horizontal, 5)
                    .ignoresSafeArea(edges: .horizontal)
                    .scrollDisabled(true)
#if DEBUG
                    .opacity(sending ? 1.0 : 0.3)
#else
                    .opacity(sending ? 1.0 : 0.01)
#endif
                }
            }
        }
        .task(id: isOpen) {
            availableVal = intValue(available)
            cash.update(availableVal)
            let maxAvailable = cash.max(available: intValue(available))
            print("OIMView.task availableVal", availableVal, maxAvailable)
            debugTick += 1
        }
        .onAppear {
            let maxAvailable = cash.max(available: intValue(available))
            print("OIMView.onAppear availableVal", availableVal, maxAvailable)
            debugTick += 1
        }
        .onDisappear {
            cash.moveBack()
            sending = false
        }
    }
}
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
    @State private var availableVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0

//    init(stack: CallStack,
//      currency: OIMcurrency,
//        amount: Binding<Amount>,
//        available: Amount,
//        useAvailable : Bool,
//        fwdButtonTapped: Binding<Bool>
//    ) {
//        // SwiftUI ensures that the initialization uses the
//        // closure only once during the lifetime of the view, so
//        // later changes to the currency have no effect.
//        self.stack = stack
//        self._amount = amount
//        self.available = available
//        self.useAvailable = useAvailable
//        self._fwdButtonTapped = fwdButtonTapped
//        self._cash = StateObject(wrappedValue: { OIMcash(currency) }())
//    }

    // available minus amountVal - what's still available from the balance when amount is on the table
    var isAvailable: UInt64 {
        if useAvailable {
            let have = intValue(available)
            let want = intValue(amount)
            if have > want {
                return have - want
            }
            return 0
        }
        return 999_999_999
    }

    var body: some View {
//        let _ = Self._printChanges()
        let _ = print(">>> OIMEditView", available, amount, stack.peek()?.file)

        OIMnavBack(stack: stack.push(),
            currencyName: cash.currency.noteBase,
                  amount: $amount,
         fwdButtonTapped: $fwdButtonTapped
        ) {
            ZStack {    // without this, money would fly below the scroller
              VStack {  // even though this is the only item in the ZStack
                Spacer()
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                        tappedVal: $tappedVal,          // <- user tapped a val in the scroller
                          canEdit: true)
                    .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace,isSource: true)
                    .zIndex(1)  // make notes fly from topZ
                    .onChange(of: amountVal) { newVal in
                        let currencyStr = amount.currencyStr
                        amount = Amount(currency: currencyStr, cent: UInt64(newVal))
                        availableVal = isAvailable
                    }
                Spacer()
                let maxAvailable = useAvailable ? cash.max(available: intValue(available)) : 0
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
//                    .onChange(of: available) { newVal in
//                        print("available from \(available) to", newVal)
//                        // disable denominations if > available
//                        availableVal = intValue(newVal) - intValue(amount)
//                    }
              }
#if DEBUG
              .border(.red)
#endif
              .task {
                  availableVal = intValue(available) - intValue(amount)
              }
            } // ZStack
        }
        .task {
            amountVal = intValue(amount)
            availableVal = isAvailable
            cash.update(amountVal)
        }
    }
}
// MARK: -
struct OIMSubjectView: View {
    let stack: CallStack
    let cash: OIMcash
    @Binding var amount: Amount
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool


    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency

        OIMnavBack(stack: stack.push(),
            currencyName: currency.noteBase,
                  amount: $amount,
         fwdButtonTapped: $fwdButtonTapped
        ) {
            VStack {
                Spacer()
                HStack {
                    Text("Subject")
                }
                Spacer()
            }
#if DEBUG
            .border(.red)
#endif
        }.task {

        }
    }
}
