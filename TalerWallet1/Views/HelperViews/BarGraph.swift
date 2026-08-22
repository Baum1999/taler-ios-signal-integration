/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

let MAXBARS = 15

struct BarGraphHeader: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    @Binding var reloadTransactions: Int

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var completedTransactions: [TalerTransaction] = []
    @ScaledMetric var barHeight = 9       // relative to fontSize

    @MainActor
    private func loadCompleted() async {
        symLog.log(".task for BarGraphHeader(\(scope.currency)) - load \(MAXBARS) Transactions")
        if let response = try? await model.getTransactionsV2(stack.push("BarGraphHeader - \(scope.url?.trimURL)"),
                                                      scope: scope,
                                              filterByState: .done,
                                                      limit: MAXBARS
        ) {
            completedTransactions = response
        }
    }

    var body: some View {
        let currencyInfo = controller.info(for: scope, controller.currencyTicker)
        HStack (alignment: .center, spacing: 10) {
            if !minimalistic || currencyInfo.hasSymbol {
                Text(currencyInfo.name)
                    .talerFont(.title2)
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
            }
            BarGraph(transactions: $completedTransactions,
                          maxBars: MAXBARS, barHeight: barHeight)
        }
//        .headerProminence(.increased)         // unfortunately this is not useful
        .task(id: reloadTransactions + 2_000_000) { await loadCompleted() }
    }
}
// MARK: -
struct BarGraph: View {
    @Binding var transactions: [TalerTransaction]
    let maxBars: Int
    let barHeight: Double

    func maxValue(_ someTransactions: [TalerTransaction]) -> Double {
        var maxValue = 0.0
        for transaction in someTransactions {
            let value = transaction.common.amountEffective.value
            if value > maxValue {
                maxValue = value
            }
        }
        return maxValue
    }

    var body: some View {
        let slice = transactions.prefix(maxBars)
        let tenTransactions: [TalerTransaction] = Array(slice)
        let maxValue = maxValue(tenTransactions)

        HStack(alignment: .center, spacing: 1) {
            if !slice.isEmpty {
                ForEach(tenTransactions, id: \.self) {transaction in
                    let common = transaction.common
                    let incoming = common.isIncoming
                    let netto = common.amountEffective.value
                    let valueColored = maxValue > 0 ? barHeight * netto / maxValue : 0
                    let valueTransparent = barHeight - valueColored
//                    let _ = print("max: \(maxValue), ", incoming ? "+" : "-", netto)
                    VStack(spacing: 0) {
                        let width = barHeight / 3
                        let topHeight = incoming ? valueTransparent : barHeight
                        let botHeight = incoming ? barHeight : valueTransparent
                        if topHeight > 0 {
                            Rectangle()
                                .opacity(INVISIBLE)
                                .frame(width: width, height: topHeight)
                        }
                        Rectangle()
                            .foregroundColor(incoming ? WalletColors().positive : WalletColors().negative)
                            .frame(width: width, height: valueColored)
                        if botHeight > 0 {
                            Rectangle()
                                .opacity(INVISIBLE)
                                .frame(width: width, height: botHeight)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)      // cannot speak out this bar chart info
        .flippedDirection()             // draw first array item on trailing edge
    }
}



#if false
#Preview {
    var sampleBars: [BarData] {
        var tempBars = [BarData]()

        for _ in 1...8 {
            let rand = Double.random(in: -100.0...100.0)

            let bar = BarData(value: rand)
            tempBars.append(bar)
        }
        return tempBars
    }

    return BarGraph(bars: sampleBars)
}
#endif
