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
struct LineMarkData: Identifiable {
    var id: String
    let distance: Int
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

    @State private var availableVal: UInt64 = 0
    @State private var available: Amount? = nil
    @State private var viewState: OIMtransactionsState = .chestIsOpen
    @State private var showChart = false
    @State private var closing = false                      // after user tapped on the open chest
    @State private var talerTXs: [TalerTransaction] = []
    @State private var chartData: [LineMarkData] = []
    @State private var chartMaxY: Double = 200              // max balance
    @State private var chartMaxX: Int = 1                // count of transactions plus spacers
    @State private var dataPointWidth: CGFloat = 100
    // when we start fetching transactions in chunks, MinX will get negative (going back in time)

    func closeHistory() {
        showChart = false
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
                    if talerTXs.count > 0 {
                        withAnimation {
                            talerTXs.removeLast()
                        }
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
        let chartButtons = HStack {
            let a11yZoomOutStr = String(localized: "Zoom out", comment: "a11y for the zoom button")
            ZoomOutButton(accessibilityLabelStr: a11yZoomOutStr) {
                if dataPointWidth > 25 {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dataPointWidth -= 10
                    }
                }
            }//.buttonStyle(.borderedProminent)
             //            Text("scroll: \(scrollPosition.pTwo)  width: \(dataPointWidth.pTwo)  maxX: \(maxXValue.pTwo)")
            Text("width: \(dataPointWidth.pTwo)")
            let a11yZoomInStr = String(localized: "Zoom in", comment: "a11y for the zoom button")
            ZoomInButton(accessibilityLabelStr: a11yZoomInStr) {
                if dataPointWidth < 185 {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dataPointWidth += 15
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
                    chartButtons.padding(.top, 4)
//                        .border(.red)
                }
                Spacer(minLength: 0)
                ZStack {
                    HStack {
                        if chartMaxX > 1 && showChart {
        let _ = print(chartMaxX, chartMaxY)
                            ChartHistoryView(currency: cash.currency,
                                            chartData: $chartData,
                                       dataPointWidth: $dataPointWidth,
                                             showData: $showChart,
                                             maxIndex: chartMaxX,
                                             maxValue: chartMaxY)
                        } else {
                            Spacer()
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
        .task {
            computeData(from: history, balance: balance.available.value)
            // set chartData, chartMaxX, chartMaxY
        }
        .onAppear {
            available = balance.available
            availableVal = available?.centValue ?? 0                            // TODO: centValue factor
            cash.update2(availableVal)           // set cash to available
            cash.setTarget(.history)
            debugTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + flyDelay) {
                showChart = true
            }
            showHistoryItems(Animation.talerDelay0)
        }
        .onDisappear {
//            cash.moveBack()
            viewState = .chestIsOpen
            showChart = false
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
        var lineMarks: [LineMarkData] = [ LineMarkData(id: "Start", distance: 0, balance: balance, talerTX: nil) ]
        var balance = balance
        var maxBalance = balance
        let calendar = Calendar.current         // or do we need (identifier: .gregorian) ?
        var lastTx = calendar.dateComponents([.year, .month, .day, .weekOfMonth], from: Date.now)
        var xIndex = 0

        func lineMark(for talerTransaction: TalerTransaction) -> LineMarkData {
            let common = talerTransaction.common
            let amount = common.amountEffective
            let incoming = common.incoming()
            let timestamp = common.timestamp
            let date = try! Date(milliseconds: timestamp.milliseconds())
            let components = calendar.dateComponents([.year, .month, .day, .weekOfMonth], from: date)
            // add spacers
            if lastTx.year != components.year {
                xIndex += 4
            } else if lastTx.month != components.month {
                xIndex += 3
            } else if lastTx.weekOfMonth != components.weekOfMonth {
                xIndex += 2
                //          } else if lastItem.weekday != components.weekday {
                //              index += 2
            } else if lastTx.day != components.day {
                xIndex += 1
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
            return LineMarkData(id: common.transactionId, distance: xIndex, balance: balance, talerTX: talerTransaction)
        }

        for talerTransaction in history {
            lineMarks.append(lineMark(for: talerTransaction))
        }

        chartData = lineMarks
        chartMaxY = maxBalance * 1.26    // 10 % plus, log2()
        chartMaxX = xIndex
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
