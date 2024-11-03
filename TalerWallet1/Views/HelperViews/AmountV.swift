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
    let scope: ScopeInfo?
    let amount: Amount
    let isNegative: Bool?       // if true, show a "-" before the amount
    let useISO: Bool
    let strikethrough: Bool
    let large: Bool             // set to false for QR or IBAN
    let a11y: String?
    
    @EnvironmentObject private var controller: Controller

    @State private var currencyInfo: CurrencyInfo?
    @State private var showBanknotes = false

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showBanknotes = false
        }
    }

    private func currencyTickerChanged() async {
        if let scope {
            currencyInfo = controller.info(for: scope)                          // might be nil!
        }
    }

    private func amountStr(_ currencyInfo : CurrencyInfo?) -> String {
        let dontShow = (isNegative == nil)
        let showSign: Bool = isNegative ?? false
        let amountFormatted: String
        if let currencyInfo {
            amountFormatted = amount.formatted(currencyInfo, isNegative: false,
                                               useISO: useISO, a11y: a11y)
        } else {
            amountFormatted = amount.readableDescription
        }
        let amountStr = dontShow ?      amountFormatted
                      : showSign ? "- \(amountFormatted)"
                                 : "+ \(amountFormatted)"
        return amountStr
    }

    var body: some View {
        Text(amountStr(currencyInfo))
            .strikethrough(strikethrough, color: .red)
            .multilineTextAlignment(.center)
            .talerFont(large ? .title : .title2)
//            .fontWeight(large ? .medium : .regular)       // @available(iOS 16.0, *)
            .monospacedDigit()
            .accessibilityLabel(amount.readableDescription)     // TODO: locale.leadingCurrencySymbol
            .task(id: controller.currencyTicker) { await currencyTickerChanged() }
//            .onLongPressGesture(minimumDuration: 0.3) {
//                showValue = true
//            }
//            .alert("Bla",
//                   isPresented: $showBanknotes,
//                   actions: {   dismissAlertButton },
//                   message: {   Text("Blub") })
    }
}
extension AmountV {
    init(_ scope: ScopeInfo?, _ amount: Amount) {
        self.stack = nil
        self.scope = scope
        self.amount = amount
        self.isNegative = false
        self.useISO = false
        self.strikethrough = false
        self.large = false
        self.a11y = nil
    }
    init(_ scope: ScopeInfo?, _ amount: Amount, isNegative: Bool?) {
        self.stack = nil
        self.scope = scope
        self.amount = amount
        self.isNegative = isNegative
        self.useISO = false
        self.strikethrough = false
        self.large = false
        self.a11y = nil
    }
    init(_ scope: ScopeInfo?, _ amount: Amount, isNegative: Bool?, strikethrough: Bool) {
        self.stack = nil
        self.scope = scope
        self.amount = amount
        self.isNegative = isNegative
        self.useISO = false
        self.strikethrough = strikethrough
        self.large = false
        self.a11y = nil
    }
    init(stack: CallStack?, scope: ScopeInfo?, amount: Amount, isNegative: Bool?,
         strikethrough: Bool, large: Bool = false) {
        self.stack = stack
        self.scope = scope
        self.amount = amount
        self.isNegative = isNegative
        self.useISO = false
        self.strikethrough = strikethrough
        self.large = false
        self.a11y = nil
    }
}
// MARK: -
//#Preview {
//    AmountV()
//}
