/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let DATAPOINTWIDTH = 60.0
let DATAPOINTWIDTH_MIN = 25.0
let DATAPOINTWIDTH_MAX = 200.0

enum OIMtransactionsState {
    case chestIsOpen
    case chestOpenTapped        // <- move money

    case balanceTapped
    case historyShown
    case historyTapped

}

// MARK: -
enum HistoryMarker: Int {
    case none
    case day
    case week
    case month
    case year
}

struct HistoryItem: Identifiable {
    var id: String {
        if let talerTX {
            return talerTX.id
        }
        return UUID().uuidString
    }
    let distance: Int
    let marker: HistoryMarker
    let balance: Double
    let talerTX: TalerTransaction?
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
    @AppStorage("oimChart") var oimChart: Bool = false                          // false = river

    @State private var availableVal: UInt64 = 0
    @State private var available: Amount? = nil
    @State private var viewState: OIMtransactionsState = .chestIsOpen
    @State private var closing = false                      // after user tapped on the open chest
    @State private var shownItems: [HistoryItem] = []
    @State private var computedItems: [HistoryItem] = []
    @State private var chartMaxY: Double = 200              // max balance
    @State private var dataPointWidth: CGFloat = DATAPOINTWIDTH
    // when we start fetching transactions in chunks, MinX will get negative (going back in time)

    func closeHistory() {
        withAnimation(.basic1) {
            viewState = .historyTapped
        }
        let delay0 = hideHistoryItems(oimChart ? Animation.talerDelay0 : 0.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay0) {
            let delay = cash.flyOneByOne(to: .idle)             // back to center
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                print("closeHistory", delay)
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
        if interval > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                let count = shownItems.count
                if count > 0 {
                    withAnimation {
                        shownItems.removeLast()
                    }
                    if count > 1 {
                        hideHistoryItems(interval)
                    }
                }
            }
            return Double(shownItems.count) * interval
        }
        shownItems = []
        return 0
    }

    @discardableResult
    func showHistoryItems(_ interval: TimeInterval = 0) -> TimeInterval {
        var delay = 0.0
        let count = computedItems.count
        let reduce = interval / Double(count + 2)
        var index = 0
        for item in computedItems {
            if interval > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        shownItems.append(item)
                    }
                }
                delay += (interval - Double(index) * reduce)
            } else {
                shownItems.append(item)
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
        let chartButtons = HStack {
            let a11yZoomOutStr = String(localized: "Zoom out", comment: "a11y for the zoom button")
            ZoomOutButton(accessibilityLabelStr: a11yZoomOutStr) {
                let width = dataPointWidth - 10
                if dataPointWidth > DATAPOINTWIDTH_MIN {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dataPointWidth = width > DATAPOINTWIDTH_MIN ? width : DATAPOINTWIDTH_MIN
                    }
                }
            }//.buttonStyle(.borderedProminent)
//            Text("scroll: \(scrollPosition.pTwo)  width: \(dataPointWidth.pTwo)  maxX: \(maxXValue.pTwo)")
//            Text("width: \(dataPointWidth.pTwo)")
            let a11yZoomInStr = String(localized: "Zoom in", comment: "a11y for the zoom button")
            ZoomInButton(accessibilityLabelStr: a11yZoomInStr) {
                let width = dataPointWidth + 15
                if dataPointWidth < DATAPOINTWIDTH_MAX {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dataPointWidth = width < DATAPOINTWIDTH_MAX ? width : DATAPOINTWIDTH_MAX
                    }
                }
            }//.buttonStyle(.borderedProminent)
        }

        OIMbackground() {
            VStack {
                ZStack(alignment: .top) {
                    OIMtitleView(cash: cash,
                               amount: available,
                              history: true, //viewState == .historyShown,
                         secondAmount: nil)

                    if #unavailable(iOS 17.0) {
                        if oimChart {
                            chartButtons.padding(.top, 4)
   //                        .border(.red)
                        }
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    HStack {
                        Spacer(minLength: 0)
                        let count = shownItems.count
                        if count > 1 {
                            let last = shownItems.last
                            let maxIndex = last?.distance ?? 20    // should never happen
                            let scrollBack = count == computedItems.count
//        let _ = print("calling HistoryView", count, maxIndex, scrollBack)
                            if oimChart {
#if TALER_WALLET
                                ChartHistoryView(stack: stack.push(),
                                              currency: cash.currency,
                                            shownItems: $shownItems,
                                        dataPointWidth: $dataPointWidth,
                                            scrollBack: scrollBack,
                                              maxIndex: maxIndex,
                                              maxValue: chartMaxY)
#else
                                ArrowHistoryView(stack: stack.push(),
                                              currency: cash.currency,
                                            shownItems: $shownItems,
                                        dataPointWidth: $dataPointWidth,
                                            scrollBack: scrollBack,
                                              maxIndex: maxIndex,
                                              maxValue: chartMaxY)
#endif
                            } else {
                                RiverHistoryView(stack: stack.push(),
                                              currency: cash.currency,
                                            shownItems: $shownItems,
                                        dataPointWidth: $dataPointWidth,
                                            scrollBack: scrollBack,
                                              maxIndex: maxIndex,
                                              maxValue: chartMaxY)
                            }
                        }
                        sidePosition
                            .padding(.leading, 20)
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
            if computedItems.count == 0 {
                computeData(from: history, balance: balance.available.value)        // set chartMaxY, computedData
            }
            showHistoryItems(oimChart ? Animation.talerDelay0 : 0.0)
        }
        .onDisappear {
//            cash.moveBack()
            viewState = .chestIsOpen
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
extension OIMtransactions {

    func computeData(from history: [TalerTransaction], balance: Double) {
        /// Algorithm for the X value of the river of time
        ///  Endpoint (now) is 0
        ///  same day transactions have no space between them
        ///  day differs: add 1 spacer
        ///  week differs: add another spacer
        ///  month differs: add one more spacer
        ///  year differs: add yet another spacer
        var historyItems: [HistoryItem] = [ HistoryItem(distance: 0, marker: .none, balance: balance, talerTX: nil) ]
        var balance = balance
        var maxBalance = balance
        let calendar = Calendar.current         // or do we need (identifier: .gregorian) ?
        var lastTx = calendar.dateComponents([.year, .month, .day, .weekOfMonth], from: Date.now)
        var xIndex = 0

        func historyItem(for talerTransaction: TalerTransaction) -> HistoryItem? {
            let common = talerTransaction.common
            let amount = common.amountEffective
            let incoming = common.isIncoming
            let pending = common.isPending
            let timestamp = common.timestamp
            let date = try! Date(milliseconds: timestamp.milliseconds())
            let components = calendar.dateComponents([.year, .month, .day, .weekOfMonth], from: date)
            // add spacers
            var marker: HistoryMarker = .none
            let isFirst = xIndex == 0
            if lastTx.year != components.year {
                xIndex += isFirst ? 1 : 4
                marker = .year
            } else if lastTx.month != components.month {
                xIndex += isFirst ? 1 : 3
                marker = .month
            } else if lastTx.weekOfMonth != components.weekOfMonth {
                xIndex += isFirst ? 1 : 2
                marker = .week
//          } else if lastItem.weekday != components.weekday {
//              index += 2
            } else if lastTx.day != components.day {
                xIndex += 1
                marker = .day
            }
            // advance to next index
            xIndex += 1
            // compute balance before that transaction
            if incoming {
                balance -= amount.value
            } else {
                balance += amount.value
            }
            lastTx = components
            if balance > maxBalance {
                maxBalance = balance
            }
            return HistoryItem(distance: xIndex, marker: marker, balance: balance, talerTX: talerTransaction)
        }

        for talerTransaction in history {
            if let item = historyItem(for: talerTransaction) {
                historyItems.append(item)
            }
        }

        computedItems = historyItems
        chartMaxY = maxBalance * yTransform(1.1)    // 10 % plus, log2()
//        print("computeData:", history.count, xIndex)
    }
}
// MARK: -


extension Double {
    var pTwo: String {
        String(format: "%.2f", self)
    }
}
extension CGFloat {
    var pTwo: String {
        String(format: "%.2f", self)
    }
}
extension CGSize {
    var pTwo: String {
        String(format: "%.2f, %.2f", self.width, self.height)
    }
}
