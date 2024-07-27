/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate let shortcuts = [5000,2500,1000,500]        // TODO: adapt for ¥

struct ShortcutButton: View {
    @Binding var currencyInfo: CurrencyInfo
    let currency: String
    let currencyField: CurrencyField
    let shortcut: Int
    let available: Amount?
    let action: (Int, CurrencyField) -> Void

    func makeButton(with newShortcut: Int) -> ShortcutButton {
        ShortcutButton(currencyInfo: $currencyInfo,
                           currency: currency,
                      currencyField: currencyField,
                           shortcut: newShortcut,
                          available: available,
                             action: action)
    }

    func isDisabled(shortie: Amount) -> Bool {
        if let available {
            do {
                return try available < shortie
            } catch {
                return true
            }
        }
        return false
    }

    var body: some View {
        let shortie = Amount(currency: currency, cent: UInt64(shortcut))        // TODO: adapt for ¥
        let title = shortie.formatted(currencyInfo, isNegative: false)
        let shortcutLabel = String(localized: "Shortcut", comment: "VoiceOver: $50,$25,$10,$5 shortcut buttons")
        Button(action: { action(shortcut, currencyField)} ) {
            Text(title)
                .lineLimit(1)
                .talerFont(.callout)
        }
//            .frame(maxWidth: .infinity)
            .disabled(isDisabled(shortie: shortie))
            .buttonStyle(.bordered)
            .accessibilityLabel("\(shortcutLabel) \(title)")
    }
}
// MARK: -
struct CurrencyInputView: View {
    @Binding var currencyInfo: CurrencyInfo
    @Binding var amount: Amount         // the `value´
    let available: Amount?
    let title: String
    let shortcutAction: ((_ amount: Amount) -> Void)?

//    @EnvironmentObject private var controller: Controller
    
    @State private var hasBeenShown = false
    @State private var showKeyboard = 0
    @State private var useShortcut = 0

    @MainActor func action(shortcut: Int, currencyField: CurrencyField) {
        let shortie = Amount(currency: amount.currencyStr, cent: UInt64(shortcut))      // TODO: adapt for ¥
        if let shortcutAction {
            shortcutAction(shortie)
        } else {
            useShortcut = shortcut
            currencyField.updateText(amount: shortie)
            amount = shortie
            currencyField.resignFirstResponder()
        }
    }

    var body: some View {
        let currency = amount.currencyStr
        let currencyField = CurrencyField($currencyInfo, amount: $amount)
        VStack (alignment: .center) {   // center shortcut buttons
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .talerFont(.title3)
                .accessibilityHidden(true)
            currencyField
                .accessibilityLabel(title)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .talerFont(.title2)
                .textFieldStyle(.roundedBorder)
                .onTapGesture {
                    if useShortcut != 0 {
                        amount = Amount.zero(currency: currency)
                        useShortcut = 0
                    }
                    showKeyboard += 1
                }
            if #available(iOS 16.0, *) {
                let shortcutButton = ShortcutButton(currencyInfo: $currencyInfo,
                                                        currency: currency,
                                                   currencyField: currencyField,
                                                        shortcut: 0,
                                                       available: available,
                                                          action: action)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        ForEach(shortcuts, id: \.self) {
                            shortcutButton.makeButton(with: $0)
                                .accessibilityAddTraits($0 == useShortcut ? .isSelected : [])
                        }
                    }
                    VStack {
                        let count = shortcuts.count
                        let half = count / 2
                        HStack {
                            Spacer()
                            ForEach(0..<half, id: \.self) { index in
                                let thisShortcut = shortcuts[index]
                                shortcutButton.makeButton(with: thisShortcut)
                                    .accessibilityAddTraits(thisShortcut == useShortcut ? .isSelected : [])
                                Spacer()
                            }
                        }
                        HStack {
                            Spacer()
                            ForEach(half..<count, id: \.self) { index in
                                let thisShortcut = shortcuts[index]
                                shortcutButton.makeButton(with: thisShortcut)
                                    .accessibilityAddTraits(thisShortcut == useShortcut ? .isSelected : [])
                                Spacer()
                            }
                        }
                    }
                    VStack {
                        ForEach(shortcuts, id: \.self) {
                            shortcutButton.makeButton(with: $0)
                                .accessibilityAddTraits($0 == useShortcut ? .isSelected : [])
                        }
                    }
                }
            } // iOS 16+ only
        }.onAppear {   // make CurrencyField show the keyboard after 0.4 seconds
            if hasBeenShown {
//                print("❗️Yikes: CurrencyInputView hasBeenShown")
            } else if !UIAccessibility.isVoiceOverRunning {
                print("❗️CurrencyInputView❗️")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    hasBeenShown = true
                    if !currencyField.becomeFirstResponder() {
                        print("❗️Yikes❗️ cannot becomeFirstResponder")
                    }
                }
            }
        }.onDisappear {
            currencyField.resignFirstResponder()
            hasBeenShown = false
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @State var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 0)
        @State private var currencyInfoL: CurrencyInfo = CurrencyInfo.zero(LONGCURRENCY)
        var body: some View {
            CurrencyInputView(currencyInfo: $currencyInfoL,
                                    amount: $amountToTransfer,
                                 available: Amount(currency: LONGCURRENCY, cent: 2000),
                                     title: "Amount to withdraw:",
                            shortcutAction: nil)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
