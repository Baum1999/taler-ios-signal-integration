/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct CurrencyInputView: View {
    @Binding var amount: Amount         // the `value´
    let title: String

    @EnvironmentObject private var controller: Controller
    
    @State var hasBeenShown = false

    var body: some View {
        let currencyInfo = controller.info(for: amount.currencyStr, controller.currencyTicker)
        let currencyField = CurrencyField(amount: $amount, currencyInfo: currencyInfo)
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
struct CurrencyInputView_Previews: PreviewProvider {
  struct StateContainer : View {
    @State var amountToTransfer = Amount(currency: LONGCURRENCY, cent: 0)

    var body: some View {
        CurrencyInputView(amount: $amountToTransfer,
                           title: "Amount to withdraw:")
    }
  }

    static var previews: some View {
        List {
            StateContainer()
        }
    }
}
#endif
