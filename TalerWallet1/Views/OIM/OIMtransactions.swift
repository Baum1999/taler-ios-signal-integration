/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

enum OIMtransactionsState {
    case chestIsOpen
    case chestOpenTapped        // <- move mon

    case balanceTapped
    case historyShown
    case historyTapped

}
// MARK: -
@available(iOS 16.4, *)
struct OIMtransactions: View {
    let stack: CallStack
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    let balance: Balance                            // this is the currency to be used
    let cash: OIMcash

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var availableVal: UInt64 = 0
    @State private var available: Amount? = nil
    @State private var viewState: OIMtransactionsState = .chestIsOpen
//    @State private var sending = false                      // after user tapped on Send or on the money
    @State private var closing = false                      // after user tapped on the open chest

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
            DispatchQueue.main.asyncAfter(deadline: .now() + Animation.talerDuration2) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dismiss()
                }
            }
        }
    }

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let sidePosition = HStack {
            Spacer()
            Color.clear
                .frame(width: 80, height: 80)
                .matchedGeometryEffect(id: OIMSIDE, in: wrapper.namespace, isSource: true)
        }
        OIMbackground() {
            ZStack(alignment: .top) {
                VStack {
                    OIMtitleView(cash: cash,
                               amount: available,
                              history: true, //viewState == .historyShown,
                         secondAmount: nil)
                    Spacer()

                    ZStack {
                        sidePosition
//                        let scaleMoney = viewState == .chestIsOpen
                        OIMlineView(stack: stack.push(),
                                     cash: cash,
                                amountVal: $availableVal,
                                  canEdit: false)
//                            .opacity(isOpen ? 1 : INVISIBLE)
//                            .scaleEffect(scaleMoney ? 0.6 : 1.0)
                            .onTapGesture {
                                closeHistory()
                            }
                    }
                    Spacer()
                } // title, money

                VStack {
                    Spacer()
                    HStack(spacing: 30) {
                            ZStack {

                            }

                    }
                    Spacer()
                } // two chests
            }
        }
        .onAppear {
            available = balance.available
            availableVal = available?.centValue ?? 0
            cash.update2(availableVal)           // set cash to available
            cash.setTarget(.history)
            debugTick += 1
        }
        .onDisappear {
//            cash.moveBack()
            viewState = .chestIsOpen
        }
    }
}
