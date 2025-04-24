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
        OIMbackground(amount: amount, currencyName: currencyName) {
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
    let available: Amount?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var qrButtonTapped: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper
    @StateObject private var cash = OIMcash()

    @State private var availableVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0
    @State private var sending = false

    func sendAction() {
        let delay = cash.moveDown()
        withAnimation(.basic1.delay(delay)) {
            sending = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {       // cash.delay
            let actionType = ActionType(animationDisabled: true)
            let userinfo = [NOTIFICATIONANIMATION: actionType]
            // will trigger NavigationLink
            NotificationCenter.default.post(name: .SendAction,
                                          object: nil,
                                        userInfo: userinfo)
        }
    }

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency

        let actions = HStack {
            QRButton(hideTitle: true) {
                // TODO: morph into view
//                var transaction = Transaction()
//                transaction.disablesAnimations = true
//                withTransaction(transaction) {
                    qrButtonTapped = true
//                }
            }
            .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))
            Spacer()
            Button(action: sendAction) {
                Image("SendTaler")
                    .resizable()
                    .scaledToFit()
                    .tint(WalletColors().talerColor)
//                    .foregroundStyle(WalletColors().talerColor)
            }
            .frame(width: 66, height: 66)
            .buttonStyle(TalerButtonStyle(type: .bordered, narrow: true, aligned: .center))
//            .buttonStyle(.bordered)
            .disabled(available?.isZero ?? true)
        }
#if DEBUG
            .border(.blue)
#endif

        OIMbackground(amount: available, currencyName: currency.noteBase) {
            ZStack(alignment: .top) {
                actions
                VStack {
                    Spacer()
                    OIMcurrencyScroller(stack: stack.push(),
                                 availableVal: $availableVal,
                                    tappedVal: $tappedVal,
                                      canEdit: false)
                    .zIndex(1)  // make notes fly from topZ
                    .clipped(antialiased: true)
                    .padding(.horizontal, 5)
                    .ignoresSafeArea(edges: .horizontal)
                    .opacity(sending ? 1.0 : 0.01)
                }
            VStack {
                Spacer()
                    OIMlineView(stack: stack.push(),
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
            }
        }
        .environmentObject(cash)
        .task {
            availableVal = intValue(available)
            cash.update(availableVal)
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMPayView: View {
    let stack: CallStack
    let amount: Amount?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)

    @EnvironmentObject private var wrapper: NamespaceWrapper
    @StateObject private var cash = OIMcash()

    @State private var amountVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency

        OIMbackground(amount: amount, currencyName: currency.noteBase) {
            VStack {
                Spacer()
                OIMlineView(stack: stack.push(),
                        amountVal: $amountVal,
                        tappedVal: $tappedVal,
                          canEdit: true)
                .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace,isSource: true)
                Spacer()
            }
#if DEBUG
            .border(.red)
#endif
        }
        .environmentObject(cash)
        .task {
            amountVal = intValue(amount)
        }

    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMEditView: View {
    let stack: CallStack
    @Binding var amount: Amount
    @Binding var available: Amount
    let useAvailable : Bool         // if false then we're requesting money and don't use available
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper
    @StateObject private var cash = OIMcash()

    @State private var amountVal: UInt64 = 0
    @State private var availableVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0

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
        let currency = cash.currency

        OIMnavBack(stack: stack.push(),
            currencyName: currency.noteBase,
                  amount: $amount,
         fwdButtonTapped: $fwdButtonTapped
        ) {
            ZStack {    // without this, money would fly below the scroller
              VStack {  // even though this is the only item in the ZStack
                Spacer()
                OIMlineView(stack: stack.push(),
                        amountVal: $amountVal,
                        tappedVal: $tappedVal,
                          canEdit: true)
                    .matchedGeometryEffect(id: "OIMline", in: wrapper.namespace,isSource: true)
                    .zIndex(1)  // make notes fly from topZ
                    .onChange(of: amountVal) { newVal in
                        let currencyStr = amount.currencyStr
                        amount = Amount(currency: currencyStr, cent: UInt64(newVal))
                        availableVal = isAvailable
                    }
                Spacer()
                OIMcurrencyScroller(stack: stack.push(),
                             availableVal: $availableVal,
                                tappedVal: $tappedVal,
                                  canEdit: true)
                    .zIndex(2)  // make notes fly from topZ
                    .clipped(antialiased: true)
                    .padding(.horizontal, 5)
                    .ignoresSafeArea(edges: .horizontal)
                    .onChange(of: available) { newVal in
                        // disable denominations if > available
                        availableVal = intValue(newVal) - intValue(amount)
                    }
              }
#if DEBUG
              .border(.red)
#endif
//                .if(.iOS15) { view in
//                    view.ignoresSafeArea(edges: .bottom)            // sadly, this does not work, because there is always a bottom bar :-(
//                }
            } // ZStack
        }
        .environmentObject(cash)
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
    @Binding var amount: Amount
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool

    @StateObject private var cash = OIMcash()

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



// MARK: -
//#Preview {
//    OIMView()
//}
