/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct AmountV: View {
    let stack: CallStack?
    @Binding var currencyInfo: CurrencyInfo
    let amount: Amount
    let isNegative: Bool?       // if true, show a "-" before the amount
    let strikethrough: Bool
    let large: Bool             // set to false for QR or IBAN

    @EnvironmentObject private var controller: Controller

    var body: some View {
        let dontShow = (isNegative == nil)
        let showSign: Bool = isNegative ?? false
        let amountFormatted = amount.formatted(currencyInfo, isNegative: false)
        let amountStr = dontShow ?      amountFormatted
                      : showSign ? "- \(amountFormatted)"
                                 : "+ \(amountFormatted)"
        Text(amountStr)
            .strikethrough(strikethrough, color: .red)
            .multilineTextAlignment(.center)
            .talerFont(large ? .title : .title2)
//            .fontWeight(large ? .medium : .regular)       // @available(iOS 16.0, *)
            .monospacedDigit()
            .accessibilityLabel(amount.readableDescription)
    }
}
extension AmountV {
    init(_ currencyInfo: Binding<CurrencyInfo>, _ amount: Amount, isNegative: Bool?) {
        self.stack = nil
        self._currencyInfo = currencyInfo
        self.amount = amount
        self.isNegative = isNegative
        self.strikethrough = false
        self.large = false
    }
    init(_ currencyInfo: Binding<CurrencyInfo>, _ amount: Amount, isNegative: Bool?, strikethrough: Bool) {
        self.stack = nil
        self._currencyInfo = currencyInfo
        self.amount = amount
        self.isNegative = isNegative
        self.strikethrough = strikethrough
        self.large = false
    }
}
// MARK: -
//#Preview {
//    AmountV()
//}
