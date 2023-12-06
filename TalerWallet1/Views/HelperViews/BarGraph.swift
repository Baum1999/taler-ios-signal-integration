/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

let MAXBARS = 10

struct BarGraphHeader: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let currency: String

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var completedTransactions: [Transaction] = []

    var body: some View {
        HStack (alignment: .center, spacing: 10) {
            Text(currency)
                .accessibilityFont(.title2)
//                .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
            BarGraph(transactions: $completedTransactions,
                     maxBars: MAXBARS, barHeight: 10)       // TODO: barHeight relative to fontSize
        }
        .task {
            symLog.log(".task for BarGraphHeader(\(currency)) - reload Transactions")
            // TODO: only load the 10 most recent transactions
            let response = await model.transactionsT(stack.push(".task - reload Transactions for \(currency)"),
                                                     currency: currency)
            completedTransactions = WalletModel.completedTransactions(response)
        }
    }
}
// MARK: -
struct BarGraph: View {
    @Binding var transactions: [Transaction]
    let maxBars: Int
    let barHeight : Double

    func maxValue(_ someTransactions: [Transaction]) -> Double {
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
        let count = slice.count
        let tenTransactions: [Transaction] = Array(slice)
        let maxValue = maxValue(tenTransactions)

        HStack(alignment: .center, spacing: 1) {
            if count > 0 {
                ForEach(Array(zip(slice.indices, slice)), id: \.0) { index, transaction in
                    let common = transaction.common
                    let incoming = common.incoming()
                    let netto = common.amountEffective.value
                    let valueColored = barHeight * netto / maxValue
                    let valueTransparent = barHeight - valueColored
//                    let _ = print("max: \(maxValue), ", incoming ? "+" : "-", netto)
                    VStack(spacing: 0) {
                        Rectangle()
                            .opacity(0.001)
                            .frame (width: 3, height: incoming ? valueTransparent : barHeight )
                        Rectangle()
                            .foregroundColor(incoming ? .green : .red)
                            .frame (width: 3, height: valueColored )
                        Rectangle()
                            .opacity(0.001)
                            .frame (width: 3, height: incoming ? barHeight : valueTransparent)
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
