/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct CurrencyInputView: View {
    @Binding var amount: Amount         // the `value´
    let title: String
    let shortcutLabel: String

    @EnvironmentObject private var controller: Controller
    
    @State var hasBeenShown = false

    var body: some View {
        let shortcuts = [50,25,10,5]
        let currency = amount.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let currencyField = CurrencyField(amount: $amount, currencyInfo: currencyInfo)
        VStack (alignment: .center) {
            HStack {
                Text(title)
//                  .padding(.top)
                    .accessibilityFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
                Spacer()
            }
            currencyField
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .accessibilityFont(.title2)
                .textFieldStyle(.roundedBorder)
            HStack {
                ForEach(shortcuts, id: \.self) { shortcut in
                    let shortie = Amount(currency: currency, integer: UInt64(shortcut), fraction: 0)
                    let title = shortie.string(currencyInfo)
                    Button(title) {
                        currencyField.updateText(amount: shortie)
                        amount = shortie
                    }.buttonStyle(.bordered)
                        .accessibilityLabel("\(shortcutLabel) \(title)")
                }
            }
        }.onAppear {   // make CurrencyField show the keyboard after 0.4 seconds
            if hasBeenShown {
//                print("❗️Yikes: CurrencyInputView hasBeenShown")
            } else {
//                print("❗️Yikes: First CurrencyInputView❗️")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    hasBeenShown = true
                    currencyField.becomeFirstResponder()
                }
            }
        }.onDisappear {
            currencyField.resignFirstResponder()
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
                               title: "Amount to withdraw:",
                       shortcutLabel: "Withdraw")
                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
