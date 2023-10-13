/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct BarGraph: View {
    @Binding var transactions: [Transaction]
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
        let slice = transactions.prefix(10)
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
