/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

fileprivate let shortcuts = [5000,2500,1000,500]        // TODO: adapt for ¥

struct ShortcutButton: View {
    let shortcut: Int
    let currency: String
    let currencyInfo: CurrencyInfo
    let currencyField: CurrencyField
    let available: Amount?
    let action: (Int, CurrencyField) -> Void

    func makeButton(with newShortcut: Int) -> ShortcutButton {
        ShortcutButton(shortcut: newShortcut,
                       currency: currency,
                   currencyInfo: currencyInfo,
                  currencyField: currencyField,
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
        let title = shortie.string(currencyInfo)
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
    @Binding var amount: Amount         // the `value´
    let available: Amount?
    let title: String
    let shortcutAction: ((_ amount: Amount) -> Void)?

    @EnvironmentObject private var controller: Controller
    
    @State private var hasBeenShown = false
    @State private var showKeyboard = 0
    @State private var useShortcut = 0

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

    var body: some View {
        let currency = amount.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let currencyField = CurrencyField(amount: $amount, currencyInfo: currencyInfo)
        VStack (alignment: .center) {   // center shortcut buttons
            HStack {
                Text(title)
                .talerFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
                Spacer()
            }
            currencyField
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
                let shortcutButton = ShortcutButton(shortcut: 0,
                                                    currency: currency,
                                                currencyInfo: currencyInfo,
                                               currencyField: currencyField,
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
            } else {
                print("❗️CurrencyInputView❗️")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    hasBeenShown = true
                    if !currencyField.becomeFirstResponder() {
                        print("❗️Yikes❗️")
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
        @StateObject private var controller = Controller.shared
        @State var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 0)
        var body: some View {
//            Preview_Content()
            CurrencyInputView(amount: $amountToTransfer,
                           available: nil,
                               title: "Amount to withdraw:",
                      shortcutAction: nil)
                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
