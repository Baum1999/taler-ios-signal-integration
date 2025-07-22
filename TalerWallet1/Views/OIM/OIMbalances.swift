/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

enum OIMbalancesState {
    case chestsClosed
    case chestClosing
    case chestOpenTapped
    case chestIsOpen

    case sendTapped
    case sending

    case requestTapped
    case requesting

    case balanceTapped
    case historyShown
    case historyTapped
}
// MARK: -
@available(iOS 16.4, *)
struct OIMbalances: View {
    let stack: CallStack
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var selectedBalance: Balance?              // return user's choice
    @Binding var selectedChestIndex: Int?               // OIM TODO: use balance
    @Binding var qrButtonTapped: Bool

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var wrapper: NamespaceWrapper

    @StateObject private var cash = OIMcash()
    @State private var availableVal: UInt64 = 0
    @State private var tappedVal: UInt64 = 0
    @State private var available: Amount? = nil
    @State private var chestOpen: Int? = nil
    @State private var viewState: OIMbalancesState = .chestsClosed
//    @State private var showingActions = false               // set true after user opened a chest, set false when choosing an action
//    @State private var sending = false                      // after user tapped on Send or on the money
    @State private var closing = false                      // after user tapped on the open chest

    func noAction() { }

    func requestTapped() {

    }

    func sendTapped() {
        withAnimation(.basicFast) {
//            showingActions = false                           //
            viewState = .sendTapped
        }
//        let delay = cash.moveDown()                                 // cash animates itself
        cash.flyOneByOne(to: .drawer)
//        withAnimation(.basic1.delay(delay + 0.5)) {
        withAnimation(.basic1.delay(0.6)) {
//            sending = true                                  // blends in the missing denominations
            viewState = .sending
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

    func closeChest() {
        if !closing {
            closing = true
            viewState = .chestClosing
            let delay = cash.flyOneByOne(to: .curve)        // back to chest...
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                print("closeChest", delay)
                withAnimation(.basic1) {
                    chestOpen = nil
                    selectedBalance = nil
                    selectedChestIndex = nil
                    available = nil
//                    showingActions = false
                    viewState = .chestsClosed
                }
                closing = false
            }
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
        viewState = .chestOpenTapped
        withAnimation(.basic1) {
            chestOpen = index
            selectedBalance = balance
            selectedChestIndex = index
            viewState = .chestIsOpen
            cash.setIndex(index)
            available = balance.available
            availableVal = balance.available.centValue
            cash.update2(availableVal, state: .chestOpening, duration, initial)  // set cash to available
            let maxAvailable = cash.max(available: availableVal)
            print("OIMView.openChest availableVal", availableVal, maxAvailable)
        }
    }

    func closeHistory() {
        withAnimation(.basic1) {
            viewState = .historyTapped
        }
        let delay = cash.flyOneByOne(to: .idle)             // back to center
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("closeHistory", delay)
            withAnimation(.basic1) {
                viewState = .chestIsOpen
            }
        }
    }

    func openHistory() {
        viewState = .balanceTapped
        let delay = cash.flyOneByOne(to: .history, true)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("openHistory", delay)
            withAnimation(.basic1) {
                viewState = .historyShown
            }
        }
    }

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let enabled = if let available {
            !available.isZero
        } else { false }
        let topButtons = HStack(alignment: .top) {
            if selectedChestIndex == nil {
                let showQR = viewState == .chestsClosed
                QRButton(hideTitle: true) {
                    qrButtonTapped = true
                }
                .opacity(showQR ? 1 : INVISIBLE)
                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                .matchedGeometryEffect(id: OIMBACK, in: wrapper.namespace, isSource: true)
            } else {
                let showRequest = viewState == .chestIsOpen
                OIMactionButton(type: .requestP2P, isFinal: false, action: requestTapped)
                    .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                    .opacity(showRequest ? 1 : INVISIBLE)
            }
            Spacer()
            let showSend = viewState == .chestIsOpen
            OIMactionButton(type: .sendP2P, isFinal: false, action: sendTapped)
                .frame(width: OIMbuttonSize, height: OIMbuttonSize)
                .opacity(showSend ? 1 : INVISIBLE)
        }

        let maxAvailable = cash.max(available: available?.centValue ?? 0)
//        let _ = print("maxAvailable", maxAvailable)

        let sidePosition = HStack {
            Spacer()
            Color.clear
                .frame(width: 80, height: 80)
                .matchedGeometryEffect(id: OIMSIDE, in: wrapper.namespace, isSource: true)
        }
        OIMbackground() {
            ZStack(alignment: .top) {
                topButtons
                VStack {
                    let isSending = viewState == .sending
                    OIMtitleView(cash: cash,
                               amount: available,
                            isSending: isSending,
                              history: viewState == .historyShown,
                         secondAmount: nil)
                    Spacer()
                    let isOpen = selectedChestIndex != nil
                    ZStack {
                        sidePosition
//                        let scaleMoney = viewState == .chestIsOpen
                        OIMlineView(stack: stack.push(),
                                     cash: cash,
                                amountVal: $availableVal,
                                  canEdit: false)
                            .opacity(isOpen ? 1 : INVISIBLE)
//                            .scaleEffect(scaleMoney ? 0.6 : 1)
                            .onTapGesture {
                                if viewState == .historyShown {
                                    closeHistory()
                                } else {
                                    openHistory()
                                }
                            }
                    }
                    Spacer()
//                    botButtons
//                        .opacity(showingActions ? 1.0 : 0.01)
                } // title, money, buttons

                VStack {
                    // two savings chests (Euro and Sierra Leone)
                    Spacer()
                    HStack(spacing: 30) {
                        let balance = controller.balances[0]
//                        ForEach(controller.balances, id: \.self) { balance in
//                            OIMbalanceButton(isOpen: selectedBalance == balance) {

                        ForEach(0..<OIMcurrencies.count, id: \.self) { index in
                            let oimCurrency = OIMcurrencies[index]
                            let itsMe = selectedChestIndex == index
                            let isClosed = selectedChestIndex == nil
                            let size = isClosed ? 160.0 : OIMbuttonSize
                            ZStack {
                                OIMbalanceButton(isOpen: itsMe, chest: oimCurrency.chest, isFinal: false) {
                                    if itsMe {
                                        closeChest()
                                    } else {
                                        openChest(index, balance)
                                    }
                                }
                                .frame(width: size, height: size)
                                .zIndex(itsMe ? 3 : 0)
                                .opacity((isClosed || itsMe) ? 1 : INVISIBLE)
                                .matchedGeometryEffect(id: itsMe ? OIMNUMBER
                                                                 : String(index),
                                                       in: wrapper.namespace, isSource: false)
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
                    let showDrawer = viewState == .sending
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
                    .opacity(showDrawer ? 1 : INVISIBLE)
                } // source for matching positions of money in the drawer
            }
        }
        .onAppear {
//            showingActions = false
            if (selectedChestIndex != nil) {
                let balance = controller.balances[0]
                available = balance.available
                availableVal = available?.centValue ?? 0
                cash.update2(availableVal)           // set cash to available
//                showingActions = true
            } else {
                availableVal = 0
                cash.update2(availableVal)           // set cash to available
            }
            debugTick += 1
        }
        .onDisappear {
            cash.moveBack()
//            sending = false
            viewState = (selectedChestIndex != nil) ? .chestIsOpen : .chestsClosed
        }
    }
}
