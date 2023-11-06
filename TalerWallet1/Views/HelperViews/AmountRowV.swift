/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

// calculate the width of the amountStr (with Font)
// calculate the width of 'content' in compact form
// if it fits side by side, then render HStack(content(compact), Spacer(), amountStr)
// else render VStack(content(wide), HStack(Spacer(), amountStr))

struct AmountRowV<Content: View>: View {
    let amountStr: String
    let amountColor: Color
    let largeAmountFont: Bool
    let fitsHorizontal: Bool
    let vertAlignment: VerticalAlignment

    var content: () -> Content


    var body: some View {
        if fitsHorizontal {
            HStack(alignment: vertAlignment, spacing: 0) {
                content()
                Spacer(minLength: 0)
                Text(amountStr)
                    .foregroundColor(amountColor)
                    .accessibilityFont(largeAmountFont ? .title : .title2)
                    .monospacedDigit()
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                content()
                HStack {
                    Spacer(minLength: 0)
                    Text(amountStr)
                        .foregroundColor(amountColor)
                        .accessibilityFont(largeAmountFont ? .title : .title2)
                        .monospacedDigit()
                }
            }
        }
    }
}
// MARK: -
#if  DEBUG

struct SectionWithAmountRow: View {
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let testInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 0)
        let demoInfo = PreviewCurrencyInfo(DEMOCURRENCY, digits: 2)
        let test = try! Amount(fromString: TESTCURRENCY + ":1.23")
        let demo = try! Amount(fromString: DEMOCURRENCY + ":1234.12")
        let testStr = test.string(testInfo)
        let demoStr = demo.string(demoInfo)
        List {
            Section {
                AmountRowV(amountStr: demoStr, amountColor: .primary, largeAmountFont: true,
                           fitsHorizontal: true, vertAlignment: .lastTextBaseline) {
                    Text(verbatim: "Balance")
                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                        .accessibilityFont(.title2)
                }
                AmountRowV(amountStr: demoStr, amountColor: .primary, largeAmountFont: true,
                           fitsHorizontal: false, vertAlignment: .lastTextBaseline) {
                    Text(verbatim: "Balance")
                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                        .accessibilityFont(.title2)
                }
            }
            Section {
                AmountRowV(amountStr: testStr, amountColor: .primary, largeAmountFont: false,
                           fitsHorizontal: true, vertAlignment: .lastTextBaseline) {
                    Text(verbatim: "Balance")
                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                        .accessibilityFont(.title2)
                }
                AmountRowV(amountStr: testStr, amountColor: .secondary, largeAmountFont: false,
                           fitsHorizontal: false, vertAlignment: .lastTextBaseline) {
                    Text(verbatim: "Balance")
                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                        .accessibilityFont(.title2)
                }
            }
        }
    }
}

#Preview {
    SectionWithAmountRow()
}
#endif
