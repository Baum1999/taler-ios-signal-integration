/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

fileprivate let replaceable = 500
fileprivate let shortcutValues = [5000,2500,1000]        // TODO: adapt for ¥

struct ShortcutButton: View {
    let scope: ScopeInfo?
    let currency: String
    let currencyField: CurrencyField
    let shortcut: Int
    let available: Amount?
    let action: (Int, CurrencyField) -> Void

    func makeButton(with newShortcut: Int) -> ShortcutButton {
        ShortcutButton(scope: scope,
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
                print("❗️Cannot compare available.\(available.currencyStr) to shortie.\(shortie.currencyStr))")
                return false
            }
        }
        return false
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let shortie = Amount(currency: currency, cent: UInt64(shortcut))        // TODO: adapt for ¥
        let title = shortie.formatted(scope, isNegative: false)
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
    let scope: ScopeInfo?
    @Binding var amount: Amount         // the `value´
    let amountLastUsed: Amount
    let available: Amount?
    let title: String?
    let shortcutAction: ((_ amount: Amount) -> Void)?

    @EnvironmentObject private var controller: Controller
    
    @State private var hasBeenShown = false
    @State private var showKeyboard = 0
    @State private var useShortcut = 0

    @MainActor
    func action(shortcut: Int, currencyField: CurrencyField) {
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

    @MainActor
    func shortcut(for value: Int,_ currencyField: CurrencyField) -> ShortcutButton {
        var shortcut = value
        if value == replaceable {
            if !amountLastUsed.isZero {
                let lastUsedD = amountLastUsed.value
                let lastUsedI = lround(lastUsedD * 100)
                if !shortcutValues.contains(lastUsedI) {
                    shortcut = lastUsedI
        }   }   }
        return ShortcutButton(scope: scope,
                           currency: amount.currencyStr,
                      currencyField: currencyField,
                           shortcut: shortcut,
                          available: available,
                             action: action)
    }

    @MainActor
    func shortcuts(_ currencyField: CurrencyField) -> [ShortcutButton] {
        var buttons = shortcutValues.map { value in
            shortcut(for: value, currencyField)
        }
        buttons.append(shortcut(for: replaceable, currencyField))
        return buttons
    }

    func heading() -> String? {
        if let title {
            return title
        }
        if let available {
            let availableStr = available.formatted(scope, isNegative: false)
            return String(localized: "Available for transfer: \(availableStr)")
        }
        return nil
    }
    var a11yLabel: String {        // format currency for a11y
        let availableStr = available?.readableDescription ?? String(localized: "unknown")
        return String(localized: "Available: \(availableStr)")
    }

    func currencyInfo() -> CurrencyInfo {
        if let scope {
            return controller.info(for: scope, controller.currencyTicker)
        } else {
            return controller.info2(for: amount.currencyStr, controller.currencyTicker)
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currencyInfo = currencyInfo()
        let currencyField = CurrencyField(currencyInfo, amount: $amount)
        VStack (alignment: .center) {   // center shortcut buttons
            if let heading = heading() {
                Text(heading)
                    .padding(.horizontal, 4)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .trailing)  // title != nil ? .leading :
                    .talerFont(.title2)
                    .accessibilityAddTraits(.isHeader)
                    .if(title == nil && available != nil) { view in
                        view.accessibilityLabel(a11yLabel)
                    }
                    .padding(.bottom, -6)
            }
            currencyField
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(WalletColors().fieldForeground)     // text color
//                .background(WalletColors().fieldBackground)       // problem: white corners
                .talerFont(.title2)
                .textFieldStyle(.roundedBorder)
                .onTapGesture {
                    if useShortcut != 0 {
                        amount = Amount.zero(currency: amount.currencyStr)
                        useShortcut = 0
                    }
                    showKeyboard += 1
                }
            if #available(iOS 16.0, *) {
                let shortcuts = shortcuts(currencyField)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        ForEach(shortcuts, id: \.shortcut) {
                            $0.accessibilityAddTraits($0.shortcut == useShortcut ? .isSelected : [])
                        }
                    }
                    VStack {
                        let count = shortcuts.count
                        let half = count / 2
                        HStack {
                            Spacer()
                            ForEach(0..<half, id: \.self) { index in
                                let thisShortcut = shortcuts[index]
                                thisShortcut
                                    .accessibilityAddTraits(thisShortcut.shortcut == useShortcut ? .isSelected : [])
                                Spacer()
                            }
                        }
                        HStack {
                            Spacer()
                            ForEach(half..<count, id: \.self) { index in
                                let thisShortcut = shortcuts[index]
                                thisShortcut
                                    .accessibilityAddTraits(thisShortcut.shortcut == useShortcut ? .isSelected : [])
                                Spacer()
                            }
                        }
                    }
                    VStack {
                        ForEach(shortcuts, id: \.shortcut) {
                            $0.accessibilityAddTraits($0.shortcut == useShortcut ? .isSelected : [])
                        }
                    }
                }
                .padding(.vertical, 6)
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
//fileprivate struct Previews: PreviewProvider {
//    @MainActor
//    struct StateContainer: View {
//        @State var amountToPreview = Amount(currency: LONGCURRENCY, cent: 0)
//        @State var amountLastUsed = Amount(currency: LONGCURRENCY, cent: 170)
//        @State private var previewL: CurrencyInfo = CurrencyInfo.zero(LONGCURRENCY)
//        var body: some View {
//            CurrencyInputView(amount: $amountToPreview,
//                              scope: <#ScopeInfo#>,
//                      amountLastUsed: amountLastUsed,
//                           available: Amount(currency: LONGCURRENCY, cent: 2000),
//                               title: "Amount to withdraw:",
//                      shortcutAction: nil)
//        }
//    }
//    static var previews: some View {
//        StateContainer()
//    }
//}
#endif
