/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let OIMbuttonSize = 80.0
let OIMactionSize = 120.0

let OIMACTION = "OIMaction"
let OIMACTION2 = "OIMaction2"
let OIMNUMBER = "OIMnumber"
let OIMCHEST = "OIMchest"

// MARK: -
struct OIMnavBack<Content: View>: View {
    let stack: CallStack
    let currencyName: String
    let isFinal: Bool                   // bordered action button
    let isSierra: Bool
    let isSending: Bool                 // move action button
    let amount: Amount?
    let action: (() -> Void)?
    var content: () -> Content

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        OIMbackground() {
            ZStack(alignment: .top) {
                content()
                VStack {
                    HStack {
                        OIMbalanceButton(isOpen: true, isSierra: isSierra, isFinal: false) {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismiss()
                            }
                        }
                            .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                        Spacer()
                        let amountIsZero = amount?.isZero ?? true
                        OIMactionButton(type: .sendP2P,
                                     isFinal: isFinal,
                                      action: amountIsZero ? nil : action)
                            .frame(width: OIMactionSize, height: OIMbuttonSize)
                            .matchedGeometryEffect(id: isSending ? OIMACTION : OIMACTION2,
                                                   in: wrapper.namespace, isSource: false)
                    }
                }
//                .border(.blue)
            }
        }
    }
}
// MARK: -
struct OIMtitleView: View {
    let cash: OIMcash
    let amount: Amount?
    let isSending: Bool
    let secondAmount: Amount?

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        HStack(alignment: .top) {
            // invisible - only serves as point where the selected balance chest moves to
            OIMbalanceButton(isOpen: true, isSierra: false, isFinal: false) {}
                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                .disabled(true)
                .opacity(0.01)
                .matchedGeometryEffect(id: OIMNUMBER, in: wrapper.namespace, isSource: true)
                .accessibilityHidden(true)

            OIMamountV(amount: amount, currencyName: cash.currency.noteBase)

            if isSending {
                Spacer()
                OIMamountV(amount: secondAmount, currencyName: cash.currency.noteBase)
            }

            OIMactionButton(type: .sendP2P, isFinal: false, action: nil)
                .frame(width: OIMactionSize, height: OIMbuttonSize)
                .disabled(true)
                .opacity(0.01)
                .matchedGeometryEffect(id: OIMACTION, in: wrapper.namespace, isSource: true)
                .accessibilityHidden(true)

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
    @State private var available: Amount? = nil
    @State private var chestOpen: Int? = nil
    @State private var showingActions = false               // set true after user opened a chest, set false when choosing an action
    @State private var sending = false                      // after user tapped on Send or on the money

    func noAction() { }

    func sendAction() {
        withAnimation(.basicFast) {
            showingActions = false                           //
        }
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

    func closeAnimated() {
        withAnimation(.basic1) {
            chestOpen = nil
            selectedBalance = nil
            selectedIndex = nil
            available = nil
            showingActions = false
        }
    }

    func openChest(_ index: Int, _ balance: Balance) {
        cash.clearFunds()
        print("❗️openChest❗️")
        let duration: TimeInterval
        let initial: TimeInterval
#if DEBUG
        duration = debugAnimations ? 2.5 :
                    fastAnimations ? 0.6 : 1.1
        initial = debugAnimations ? 1.0 : 0.1
#else
        duration = fastAnimations ? 0.6 : 1.1
        initial = 0.1
#endif
        withAnimation(.basic1) {
            chestOpen = index
            selectedIndex = index
            cash.currency = index == 0 ? OIMeuros : OIMleones
            selectedBalance = balance
            available = balance.available
            availableVal = balance.available.centValue
            cash.update2(availableVal, state: .chestOpening, duration, initial)  // set cash to available
            let maxAvailable = cash.max(available: availableVal)
            print("OIMView.openChest availableVal", availableVal, maxAvailable)
        }
    }

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let enabled = if let available {
            !available.isZero
        } else { false }
        let topButtons = HStack(alignment: .top) {
            QRButton(hideTitle: true) {
                qrButtonTapped = true
            }
                .opacity(sending ? 0.01 : 1.0)
                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                .matchedGeometryEffect(id: "OIMback", in: wrapper.namespace, isSource: true)
            Spacer()
//            OIMsendButton(isGoal: false, isFinal: false, enabled: enabled, action: sendAction)
//                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
        }

        let maxAvailable = cash.max(available: available?.centValue ?? 0)
//        let _ = print("maxAvailable", maxAvailable)

        let botButtons = HStack() {
            let buttons: [OIMactions] = [.deposit, .withdrawal, .requestP2P, .sendP2P].shuffled()
            Spacer()
            ForEach(buttons, id: \.self) { button in
                let action = switch button {
                    case .sendP2P:      sendAction
                    case .withdrawal:   noAction
                    case .deposit:      noAction
                    case .requestP2P:   noAction
                }
                OIMactionButton(type: button, isFinal: false, action: action)
                    .frame(width: OIMactionSize, height: OIMactionSize)
                Spacer()
            }
        }

        OIMbackground() {
            ZStack(alignment: .top) {
                topButtons
                VStack {
                    OIMtitleView(cash: cash, amount: available, isSending: sending, secondAmount: nil)
                    Spacer()
                    let isOpen = chestOpen != nil
                    OIMlineView(stack: stack.push(),
                                 cash: cash,
                            amountVal: $availableVal,
                            tappedVal: $tappedVal,
                              canEdit: false)
                        .opacity(isOpen ? 1.0 : 0.01)
                        .scaleEffect(showingActions ? 0.6 : 1.0)
                        .onTapGesture {
                            withAnimation(.basic1) {
                                showingActions.toggle()
                            }
                        }
                    Spacer()
                    botButtons
                        .opacity(showingActions ? 1.0 : 0.01)
                } // title, money, buttons

                VStack {
                    // two savings chests (Euro and Sierra Leone)
                    Spacer()
                    HStack(spacing: 30) {
//                        ForEach(controller.balances, id: \.self) { balance in
//                            OIMbalanceButton(isOpen: selectedBalance == balance) {

                        let balance = controller.balances[0]
                        ForEach(0...1, id: \.self) { index in
                            let itsMe = chestOpen == index
                            let isClosed = chestOpen == nil
                            let size = isClosed ? 160.0 : OIMbuttonSize
                            ZStack {
                                OIMbalanceButton(isOpen: itsMe, isSierra: index > 0, isFinal: false) {
                                    if itsMe {
                                        closeAnimated()
                                    } else {
                                        openChest(index, balance)
                                    }
                                }
                                .frame(width: size, height: size)
                                .zIndex(itsMe ? 3 : 0)
                                .opacity((isClosed || itsMe) ? 1.0 : 0.01)
                                .matchedGeometryEffect(id: itsMe ? OIMNUMBER // (sending ? "OIMback" : OIMNUMBER)
                                                                 : String(index),
                                                       in: wrapper.namespace, isSource: false)
                                .frame(width: size, height: size)
                                Color.clear
                                    .frame(width: 40, height: 40)
                                    .matchedGeometryEffect(id: OIMCHEST + String(index), in: wrapper.namespace, isSource: true)
                            }
                        }
                    }
                    Spacer()
                } // two chests

                VStack {
                    Spacer()
                    OIMcurrencyDrawer(stack: stack.push(),
                                       cash: cash,
                               availableVal: $availableVal,
                                  tappedVal: $tappedVal,
                             scrollPosition: maxAvailable,
                                    canEdit: false)
                    .clipped(antialiased: true)
                    .padding(.horizontal, 5)
                    .ignoresSafeArea(edges: .horizontal)
                    .scrollDisabled(true)
                    .opacity(sending ? 1.0 : 0.01)
                } // for matching positions of money
            }
        }
        .onAppear {
            showingActions = false
            if (chestOpen != nil) {
                let balance = controller.balances[0]
                available = balance.available
                availableVal = available?.centValue ?? 0
                cash.update2(availableVal)           // set cash to available
                showingActions = true
            } else {
                availableVal = 0
                cash.update2(availableVal)           // set cash to available
            }
            debugTick += 1
        }
        .onDisappear {
            cash.moveBack()
            sending = false
        }
    }
}
