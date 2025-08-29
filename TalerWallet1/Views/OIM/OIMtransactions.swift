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
    case chestOpenTapped        // <- move money

    case balanceTapped
    case historyShown
    case historyTapped

}

// MARK: -
struct OIMhistoryItem: View {
    let talerTX: TalerTransaction

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let common = talerTX.common
        let value = common.amountEffective.valueStr
        let incoming = common.incoming()
        let isDark = colorScheme == .dark
        let increasedContrast = colorSchemeContrast == .increased
        let badge = TransactionIconBadge(from: talerTX, isDark: isDark, increasedContrast)
                        .talerFont(.largeTitle)
        let amount = Text("\(value)")
            .talerFont(.title1)
        VStack {
            if incoming {
                badge
                amount
            } else {
                amount
                badge
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMtransactions: View {
    let stack: CallStack
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    let balance: Balance                            // this is the currency to be used
    let cash: OIMcash
    let history: [TalerTransaction]

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var availableVal: UInt64 = 0
    @State private var available: Amount? = nil
    @State private var viewState: OIMtransactionsState = .chestIsOpen
    @State private var closing = false                      // after user tapped on the open chest
    @State private var talerTXs: [TalerTransaction] = []

    func closeHistory() {
        withAnimation(.basic1) {
            viewState = .historyTapped
        }
        let delay0 = hideHistoryItems(Animation.talerDelay0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay0) {
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
    }

    @discardableResult
    func hideHistoryItems(_ interval: TimeInterval = 0) -> TimeInterval {
        var delay = 0.0
        var count = talerTXs.count
        while count > 0 {
            if interval > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        talerTXs.removeLast()
                        return      // Conflicting arguments to generic parameter 'Result' ('Void' vs …)
                    }
                }
                delay += interval
            } else {
                talerTXs.removeLast()
            }
            count -= 1
        }
        return delay
    }

    @discardableResult
    func showHistoryItems(_ interval: TimeInterval = 0) -> TimeInterval {
        var delay = 0.0
        for talerTX in history {
            if interval > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        talerTXs.append(talerTX)
                    }
                }
                delay += interval
            } else {
                talerTXs.append(talerTX)
            }
        }
        return delay
    }

    var body: some View {
        var debugTick = 0
//        let _ = Self._printChanges()

        let sidePosition = Color.clear
                            .frame(width: 80, height: 80)
                            .matchedGeometryEffect(id: OIMSIDE, in: wrapper.namespace, isSource: true)

        OIMbackground() {
            VStack {
                OIMtitleView(cash: cash,
                           amount: available,
                          history: true, //viewState == .historyShown,
                     secondAmount: nil)
                Spacer(minLength: 0)
                ZStack {
                    HStack {
                        ScrollView(.horizontal) {
                            LazyHStack {
                                ForEach(talerTXs) { talerTX in
                                    OIMhistoryItem(talerTX: talerTX)
                                        .flippedLeftRight()
                                        .padding(.horizontal)
//                                        .transition(.backslide)
                                    Spacer()
                                }
                            }
                            //.border(.red)
                        }.flippedLeftRight()
                        sidePosition
                            .padding(.leading, 35)
                    }// .border(.blue)
                    OIMlineView(stack: stack.push(),
                                 cash: cash,
                            amountVal: $availableVal,
                              canEdit: false)
//                  .opacity(isOpen ? 1 : INVISIBLE)
//                  .scaleEffect(scaleMoney ? 0.6 : 1.0)
                    .onTapGesture {
                        closeHistory()
                    }
                }
                Spacer(minLength: 0)
            } // title, HStack
        }
        .onAppear {
            available = balance.available
            availableVal = available?.centValue ?? 0                            // TODO: centValue factor
            cash.update2(availableVal)           // set cash to available
            cash.setTarget(.history)
            debugTick += 1
            showHistoryItems(Animation.talerDelay0)
        }
        .onDisappear {
//            cash.moveBack()
            viewState = .chestIsOpen
        }
    }
}
