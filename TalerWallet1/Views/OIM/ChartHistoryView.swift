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
    private let logger = Logger(subsystem: "net.taler.gnu", category: "Chart")
    let currency: OIMcurrency
    @Binding var chartData: [LineMarkData]
    @Binding var dataPointWidth: CGFloat
    @Binding var showData: Bool

    @State private var maxXValue: Int           // #of dataPoints in history, plus spacers
    @State private var maxYValue: Double        // max balance

    @Namespace var chartID
    @State var scrollPosition: Double = 0
    @State var selectedTX: Int? = nil

    init(currency: OIMcurrency, chartData: Binding<[LineMarkData]>, dataPointWidth: Binding<CGFloat>,
         showData: Binding<Bool>, maxIndex: Int = 1, maxValue: Double = 200) {
        self.currency = currency
        self._showData = showData
        self._chartData = chartData
        self._dataPointWidth = dataPointWidth
        self.maxYValue = maxValue
        self.maxXValue = maxIndex
    }

    var lineMarkforSelection: LineMarkData? {
        if let selectedTX {
            for lineMark in chartData {
                if lineMark.distance == -selectedTX {
                    return lineMark
                }
            }
        }
        return nil
    }


    var body: some View {
//        let stroke = StrokeStyle(lineWidth: CGFloat,
//                                 lineCap: CGLineCap,
//                                 lineJoin: CGLineJoin,
//                                 miterLimit: CGFloat,
//                                 dash: [CGFloat],
//                                 dashPhase: CGFloat)
        let count = chartData.count
        let chart = Chart {
            ForEach(0..<count, id: \.self) { index in
                let data = chartData[index]
                let xVal = -data.distance
                let yVal = yTransform(data.balance)
                LineMark(x: .value("x", xVal),
                         y: .value("y", yVal))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                // 0 = uniform spline, 0.5 = centripetal spline, 1.0 = chordal spline
                // See https://en.wikipedia.org/wiki/File:Catmull-Rom_examples_with_parameters..png
                .interpolationMethod(.catmullRom(alpha: 0.5))       // centripetal

                if let talerTX = data.talerTX {
                    PointMark(x: .value("x", xVal),
                              y: .value("y", yVal))

                    .symbolSize(0) // hide the existing symbol
                    .annotation(position: .overlay, alignment: .center) {
                        let isSelected = xVal == selectedTX
                        ChartHistoryBadge(talerTX: talerTX)
                            .id(index)
                            .scaleEffect(isSelected ? 1.8 : 1.0)
                    }
                }
            }
        }.id(chartID)
        .chartXScale(domain: -Double(maxXValue)...0.2)
        .chartXAxis { }
        .chartYScale(domain: -yTransform(maxYValue / 10)...yTransform(maxYValue))
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel(horizontalSpacing: 16)
            }
        }
        .chartLegend(.hidden)
        .frame(width: dataPointWidth * CGFloat(count))
//        .chartOverlay { chartProxy in
//            Rectangle().fill(.clear).contentShape(Rectangle())
//                .gesture(
//                    magnification//.simultaneously(with: select)
//                )
//        }

        ZStack(alignment: .top) {
            if showData {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal) {
                        if #available(iOS 17.0, *) {
                            chart
                                .chartXSelection(value: $selectedTX)
                        } else {
                            chart
                        }
                    }

                    .task {
                        logger.log("Task")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            logger.log("Scrolling")
                            withAnimation(.easeOut(duration: 5.0)) {
                                scrollProxy.scrollTo(chartID, anchor: .bottomTrailing)
                            }
                        }
                    }

                    .onTapGesture(count: 2) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            dataPointWidth = 100        // reset the scale first
                            scrollProxy.scrollTo(chartID, anchor: .bottomTrailing)
                        }
                    }
                    //                Button("Top") { withAnimation { proxy.scrollTo(topID) } }
                }
                if let selectedTX {
                    if let lineMark = lineMarkforSelection {
                        if let talerTX = lineMark.talerTX {
                            // TODO: hero animation from index
                            VStack {
                                Spacer()
                                let common = talerTX.common
                                let eff = common.amountEffective
                                let balance =  lineMark.balance * Double(currency.factor)
                                VStack {
                                    Text("Balance: \(balance.pTwo)")
                                    OIMamountV(amount: eff, currencyName: currency.currencyStr, factor: currency.factor)
                                }
                                .padding()
                                .background(WalletColors().backgroundColor)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}
