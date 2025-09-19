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
fileprivate let river_back = "river-back"

// MARK: -
@available(iOS 16.4, *)
struct RiverHistoryView: View {
    let stack: CallStack
    private let logger = Logger(subsystem: "net.taler.gnu", category: "River")
    let currency: OIMcurrency
    @Binding var shownItems: [HistoryItem]
    @Binding var dataPointWidth: CGFloat
    let scrollBack: Bool

    let maxXValue: Int           // #of dataPoints in history, plus spacers
    @State private var maxYValue: Double        // max balance

    @Namespace var riverID
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

    func selectTX(_ selected: Int?) {
        withAnimation {
            selectedTX = selected
        }
    }

    func historyItem(for xVal: Int) -> HistoryItem? {
        for item in shownItems {
            if item.distance == -xVal {
                return item
            }
        }
        return nil
    }

    var body: some View {
        let count = shownItems.count
//    let _ = logger.log("RiverHistoryView \(width.pTwo)")

        ZStack(alignment: .top) {
            ScrollViewReader { scrollProxy in
                OptimalSize(.horizontal) {      // keep it small if we have only a few tx
                    ScrollView(.horizontal) {
                        if count > 0 {
                            HStack(spacing: 0) {
                                ForEach(-maxXValue...0, id: \.self) { xVal in
                                    RiverTileView(historyItem: historyItem(for: xVal)) {
                                        selectTX(xVal)
                                    }
                                }
                            }.id(riverID)
                        }
                    }
                    //.border(.blue)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)      // don't bounce if it's small
                    .task(id: scrollBack) {
                        logger.log("Task \(scrollBack)")
                        if scrollBack {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                logger.log("Scrolling")
                                withAnimation() {       // .easeOut(duration: 3.0)  doesn't work, always uses standard timing
                                    scrollProxy.scrollTo(riverID, anchor: .bottomTrailing)
                                }
                            }
                        }
                    }
                    .onTapGesture(count: 2) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            dataPointWidth = 100        // reset the scale first
                            scrollProxy.scrollTo(riverID, anchor: .bottomTrailing)
                        }
                    }
                }
            } // ScrollViewReader
            if let selectedTX {
                if let item = historyItem(for: selectedTX) {
                    if let talerTX = item.talerTX {
                        HistoryDetailView(stack: stack.push(),
                                       currency: currency,
                                        balance: item.balance,
                                        talerTX: talerTX)
                        .onTapGesture { selectTX(nil) }
                    }
                }
            }
        } // ZStack
    }
}
// MARK: -
struct RiverTileView: View {
    let historyItem: HistoryItem?
    let selectTX: () -> Void

    func sizeIn(for value: Double) -> Int {
        if value < 100 { return 0 }
        if value < 300 { return 1 }
        if value < 500 { return 2 }
        if value < 750 { return 3 }
        else { return 4 }
    }

    func sizeOut(for value: Double) -> Int {
        if value < 31 { return 0 }
        if value < 80 { return 1 }
        if value < 200 { return 2 }
        if value < 500 { return 3 }
        else { return 4 }
    }

    var body: some View {
        let txValue = historyItem?.talerTX?.common.amountEffective.value ?? 0
//        let width = width(for: txValue)
        let tree = Image("Tree-without-shadow")
            .resizable()

        let treeSpace = 15.0
        let background = VStack(spacing: 0) {
            Color.brown     // TODO: add some random trees
                .overlay(alignment: .topLeading) {
                    GeometryReader { geo in
                        let height = geo.size.height
                        let width = geo.size.width
//                        let _ = print("width = \(width), height = \(height)")
                        let treeCount = Int.random(in: 23...57)
                        ForEach(0..<treeCount, id: \.self) { treeIndex in
                            let xOffset = Double.random(in: 3...width-treeSpace)
                            let yOffset = Double.random(in: 3...height-treeSpace)
                            let treeSize = Double.random(in: 10...20)
                            tree.frame(width: treeSize, height: treeSize)
                                .offset(x: xOffset, y: yOffset)
                        }
                    }
                }
            Color.yellow
        }

        // transactions
        if let historyItem {
            if let talerTX = historyItem.talerTX {
                let common = talerTX.common
                let amount = common.amountEffective
                if common.isIncoming {
                    let sizeIndex = sizeIn(for: amount.value)
                    Image("River-Lake-" + String(sizeIndex))
                        .resizable()
                        .scaledToFit()
//                        .border(.red)
                        .onTapGesture { selectTX() }
                        .background { background }
                } else if common.isOutgoing {
                    let sizeIndex = sizeOut(for: amount.value)
                    Image("River-Pond-" + String(sizeIndex))
                        .resizable()
                        .scaledToFit()
//                        .border(.red)
                        .onTapGesture { selectTX() }
                        .background { background }
                }
            } else {
                let _ = print("no talerTX")
            }
        } else {
            let _ = print("no historyItem")
        }
        //.border(.green)
        //.border(.blue)
    }
}
