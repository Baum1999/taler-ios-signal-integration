/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
    let available: Amount?                      // disable if available < value
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
            return available.value < shortie.value
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
        let shortcutLabel = String(localized: "Shortcut", comment: "a11y: $50,$25,$10,$5 shortcut buttons")
        let a11yLabel = "\(shortcutLabel) \(title.1)"
        Button(action: { action(shortcut, currencyField)} ) {
            Text(title.0)
                .lineLimit(1)
                .talerFont(.callout)
        }
//            .frame(maxWidth: .infinity)
            .disabled(isDisabled(shortie: shortie))
            .buttonStyle(.bordered)
            .accessibilityLabel(a11yLabel)
    }
}
// MARK: -
struct CurrencyInputView: View {
    let scope: ScopeInfo?
    @Binding var amount: Amount         // the `value´
    let amountLastUsed: Amount
    let available: Amount?
    let title: String?
    let a11yTitle: String
    let shortcutAction: ((_ amount: Amount) -> Void)?

    @EnvironmentObject private var controller: Controller
    
    @State private var hasBeenShown = false
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
    func shortcuts(_ currencyField: CurrencyField, _ currencyInfo: CurrencyInfo) -> [ShortcutButton] {
        var buttons: [ShortcutButton] = []
        if let commonAmounts = currencyInfo.commonAmounts {
            buttons = commonAmounts.prefix(4).map { amount in
                shortcut(for: Int(amount.centValue), currencyField)
            }
        } else {
            buttons = shortcutValues.map { value in
                shortcut(for: value, currencyField)
            }
            buttons.append(shortcut(for: replaceable, currencyField))
        }
        return buttons
    }

    func availableString(_ availableStr: String) -> String {
        String(localized: "Available for transfer: \(availableStr)")
    }

    var a11yLabel: String {        // format currency for a11y
        availableString(available?.readableDescription ?? String(localized: "unknown"))
    }

    func heading() -> (String, String)? {
        if let title {
            return (title, title)
        }
        if let available {
            let formatted = available.formatted(scope, isNegative: false)
            return (availableString(formatted.0), availableString(formatted.1))
        }
        return nil
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
                Text(heading.0)
                    .padding(.horizontal, 4)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: title != nil ? .leading : .trailing)
                    .talerFont(.title2)
                    .accessibilityLabel(heading.1)
                    .padding(.bottom, -6)
            }
            currencyField
                .accessibilityLabel(a11yTitle)
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
                }
            if #available(iOS 16.4, *) {
                let shortcuts = shortcuts(currencyField, currencyInfo)
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
#if OIM
            let oimModeActive = controller.oimModeActive
#else
            let oimModeActive = false
#endif
            if hasBeenShown {
//                print("❗️Yikes: CurrencyInputView hasBeenShown")
            } else if !UIAccessibility.isVoiceOverRunning && !oimModeActive {
//                print("❗️CurrencyInputView❗️")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    hasBeenShown = true
                    if !oimModeActive {
                        if !currencyField.becomeFirstResponder() {
                            print("❗️Yikes❗️ cannot becomeFirstResponder")
                        }
                    }
                }
            }
        }.onDisappear {
            currencyField.resignFirstResponder()
            hasBeenShown = false
        }
#if OIM
        .onChange(of: controller.oimModeActive) {_ in
            currencyField.resignFirstResponder()
        }
#endif
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
