/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct CurrencyInputView: View {
    let currencyField: CurrencyField
    let title: String

    @State var hasBeenShown = false
    var body: some View {
        VStack (alignment: .leading) {
            Text(title)
//                .padding(.top)
                .accessibilityFont(.title3)
            currencyField
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .accessibilityFont(.title2)
                .textFieldStyle(.roundedBorder)
        }.onAppear {   // make CurrencyField show the keyboard after 0.4 seconds
            if hasBeenShown {
                print("❗️Yikes: CurrencyInputView hasBeenShown")
            } else {
                print("❗️Yikes: First CurrencyInputView❗️")
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
fileprivate struct BindingViewContainer : View {
    @State var centsToTransfer: UInt64 = 0

    var body: some View {
        let currencyField = CurrencyField(value: $centsToTransfer, currency: LONGCURRENCY)
        CurrencyInputView(currencyField: currencyField,
                                  title: "Amount to withdraw:")
    }
}

struct CurrencyInputView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            BindingViewContainer()
        }
    }
}
#endif
