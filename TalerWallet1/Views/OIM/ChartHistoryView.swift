/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import Charts
import os.log
import SymLog
import taler_swift

fileprivate let lineWidth = 6.0

func yTransform(_ yVal: Double) -> Double {
#if OIMx
    log2(yVal)
#else
    yVal
#endif
}

// MARK: -
struct ChartHistoryBadge: View {
    let talerTX: TalerTransaction?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let isDark = colorScheme == .dark
        let increasedContrast = colorSchemeContrast == .increased
        if let talerTX {
            TransactionIconBadge(from: talerTX, isDark: isDark, increasedContrast)
                .talerFont(.largeTitle)
        }
    }
}

// MARK: -
@available(iOS 16.4, *)
struct ChartHistoryView: View {
    let stack: CallStack
    private let logger = Logger(subsystem: "net.taler.gnu", category: "Chart")
    let currency: OIMcurrency
    @Binding var shownItems: [HistoryItem]
    @Binding var dataPointWidth: CGFloat
    let scrollBack: Bool

    let maxXValue: Int           // #of dataPoints in history, plus spacers
    @State private var maxYValue: Double        // max balance

    @Namespace var chartID
    @State private var scrollPosition: Double = 0
    @State private var selectedTX: Int? = nil
    @State private var selectedY: Double? = nil
    @State private var selectedRange: ClosedRange<Double>?
    @State private var lastDelta: Double?

    init(stack: CallStack,
      currency: OIMcurrency, shownItems: Binding<[HistoryItem]>, dataPointWidth: Binding<CGFloat>,
         scrollBack: Bool, maxIndex: Int = 1, maxValue: Double = 200
    ) {
        self.stack = stack
        self.currency = currency
        self.scrollBack = scrollBack
        self._shownItems = shownItems
        self._dataPointWidth = dataPointWidth
        self.maxYValue = maxValue
        self.maxXValue = maxIndex
    }

    var itemForSelection: HistoryItem? {
        if let selectedTX {
            for item in shownItems {
                if item.distance == -selectedTX {
                    return item
                }
            }
        }
        return nil
    }

    func isTapped(y: Double) -> Bool {
        if let selectedY {
            return abs(y - selectedY) < 5
        }
        return false
    }

    func magnify(_ newDelta: Double) -> Bool {
        if let lastDelta {
            let delta = newDelta - lastDelta
            let absDelta = abs(delta)
    print(absDelta.pTwo)
            var width = dataPointWidth
            if delta > 0.1 {              // zoom in
//                width += 10
                width += absDelta * 10
                dataPointWidth = width < DATAPOINTWIDTH_MAX ? width : DATAPOINTWIDTH_MAX
            } else if delta < -0.1 {       // zoom out
//                width -= 10
                width -= absDelta * 10
                dataPointWidth = width > DATAPOINTWIDTH_MIN ? width : DATAPOINTWIDTH_MIN
            } else {
                return false
            }
        }
        return true
    }

    var body: some View {
        let count = shownItems.count
        let width = dataPointWidth * CGFloat(maxXValue)
//    let _ = logger.log("ChartHistoryView \(width.pTwo)")
        let chart = Chart {
            ForEach(0..<count, id: \.self) { index in
                let item = shownItems[index]
                let xVal = -item.distance
                let yVal = yTransform(item.balance)
                LineMark(x: .value("x", xVal),
                         y: .value("y", yVal))
                .foregroundStyle(WalletColors().primaryAccent)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                // 0 = uniform spline, 0.5 = centripetal spline, 1.0 = chordal spline
                // See https://en.wikipedia.org/wiki/File:Catmull-Rom_examples_with_parameters..png
//                .interpolationMethod(.catmullRom(alpha: 0.5))       // centripetal
                .interpolationMethod(.monotone)
//                .interpolationMethod(.stepCenter) // stepStart

                if let talerTX = item.talerTX {
                    PointMark(x: .value("x", xVal),
                              y: .value("y", yVal))

                    .symbolSize(0) // hide the existing symbol
                    .annotation(position: .overlay, alignment: .center) {
                        let isSelected = xVal == selectedTX
                        let isTapped = isTapped(y: yVal)
                        if isSelected && isTapped {
                            let _ = logger.log("annotation \(xVal) \(yVal.pTwo) \(selectedY ?? 0)")
                        }
                        ChartHistoryBadge(talerTX: talerTX)
                            .id(index)
                            .scaleEffect(isSelected ? 1.8 : 1.0)
                    }
                } else if xVal == 0 {
//        let _ = logger.log("PointMark \(xVal) \(yVal.pTwo)")
                    PointMark(x: .value("x", xVal),
                              y: .value("y", yVal))
                    .symbol(symbol: {
                        Image(systemName: BANKNOTE)      // wallet.bifold.fill
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25)
                            .foregroundStyle(WalletColors().primaryAccent)
                    })
                }
            }
        }.id(chartID)
        .chartXScale(domain: -Double(maxXValue)-0.4...0.1)
        .chartXAxis { }
        .chartYScale(domain: -yTransform(maxYValue / 10)...yTransform(maxYValue))
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .trailing) { _ in
                AxisGridLine()
                AxisValueLabel(horizontalSpacing: 16)
            }
        }
        .chartLegend(.hidden)
        .frame(width: width)
        .onChange(of: selectedRange) { newRange in
            if let newRange {               // pinch started - or changed
                let newDelta = newRange.upperBound - newRange.lowerBound
//                logger.log("selectedRange \(newDelta)")
                if magnify(newDelta) {
                    lastDelta = newDelta
                }
            } else {                        // pinch ended
                lastDelta = nil
            }
        }
        ZStack(alignment: .top) {
            ScrollViewReader { scrollProxy in
                OptimalSize(.horizontal) {
                    ScrollView(.horizontal) {
                        if #available(iOS 17.0, *) {
                            chart
                                .chartYSelection(value: $selectedY)
                                .chartXSelection(value: $selectedTX)
                                .chartXSelection(range: $selectedRange)
//                                .border(.red)
                        } else {
                            chart
                        }
                    }//.border(.blue)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .task(id: scrollBack) {
                        logger.log("Task")
                        if scrollBack {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                logger.log("Scrolling")
                                withAnimation() {       // .easeOut(duration: 3.0)  doesn't work, always uses standard timing
                                    scrollProxy.scrollTo(chartID, anchor: .bottomTrailing)
                                }
                            }
                        }
                    }

                    .onTapGesture(count: 2) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            dataPointWidth = 100        // reset the scale first
                            scrollProxy.scrollTo(chartID, anchor: .bottomTrailing)
                        }
                    }
                }
//                Button("Top") { withAnimation { proxy.scrollTo(topID) } }
            } // ScrollViewReader
            if let selectedTX {
                if let item = itemForSelection {
                    if let talerTX = item.talerTX {
                        ChartOverlayV(stack: stack.push(),
                                   currency: currency,
                                    balance: item.balance,
                                    talerTX: talerTX)
                    }
                }
            }
        } // ZStack
    }
}
// MARK: -
@available(iOS 16.4, *)
struct ChartOverlayV: View {
    let stack: CallStack
    let currency: OIMcurrency
    let balance: Double
    let talerTX: TalerTransaction
    let effective: Amount

    @StateObject private var cash: OIMcash
    @State private var amountVal: UInt64 = 0
    @Namespace var namespace

    init(stack: CallStack,
      currency: OIMcurrency,
       balance: Double,
       talerTX: TalerTransaction
    ) {
        self.stack = stack
        self.currency = currency
        self.balance = balance
        self.talerTX = talerTX
        let oimCash = OIMcash(currency)
        self._cash = StateObject(wrappedValue: { oimCash }())
        let common = talerTX.common
        let eff = common.amountEffective
        self.effective = eff
        let cents = eff.centValue
        self._amountVal = State(wrappedValue: { cents }())
//        print("ChartOverlayV init:", cents)
    }

    var body: some View {
        // TODO: hero animation from index
        VStack {
            Spacer()
            let balance2 =  balance * Double(currency.factor)
            let incoming = talerTX.common.isIncoming
            VStack {
                Text("Balance: \(balance2.pTwo)")
                    .foregroundStyle(WalletColors().gray2)
                OIMamountV(amount: effective, currencyName: currency.currencyStr,
                           factor: currency.factor, mayChangeSpeed: false)
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                          canEdit: false)
//                .opacity(isOpen ? 1 : INVISIBLE)
//                .scaleEffect(scaleMoney ? 0.6 : 1)
            }.environmentObject(NamespaceWrapper(namespace))         // keep OIMviews apart
            .padding()
            .onAppear {
                cash.update2(amountVal)             // set cash to talerTX.common.effective
            }
            .onChange(of: effective) { newVal in
                print("ChartOverlayV onChange of:", newVal)
                let cents = newVal.centValue
                cash.update2(cents)                 // set cash to talerTX.common.effective
            }
            .background(
                RoundedRectangle(cornerRadius: 30).style(
                    withStroke: Color.primary,
                    lineWidth: 2,
                    fill: LinearGradient(
                        gradient: Gradient(colors: [WalletColors().transactionColor(incoming), .white]),
                      startPoint: .top,
                        endPoint: .bottom
                    ).opacity(0.85)
                )
            )
            Spacer()
        }
    }
}
