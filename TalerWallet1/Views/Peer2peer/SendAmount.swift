/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SendAmount: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Send Coins")
//    @ObservedObject private var keyboardResponder = KeyboardResponder()
//    @FocusState private var isFocused: Bool

    let amountAvailable: Amount
    let buttonFont: Font = .title2

    @State private var centsToTransfer: UInt64 = 0        // TODO: maybe Decimal?
    @State private var purpose: String = ""
    @State private var expireDays: UInt = 0

    var body: some View {
        let currencyField = CurrencyField(value: $centsToTransfer, currency: amountAvailable.currencyStr)

        VStack(alignment: .leading, spacing: 6) {
            CurrencyInputView(currencyField: currencyField, title: "Amount to send:")

            let available = amountAvailable.readableDescription
            Text("Available: \(available)")

            Text("Choose where to send to:")
                .padding(.top)
                .font(.title3)
            HStack {
                let kbdShown: Bool = false  // keyboardResponder.keyboardHeight > 0
                let title1 = kbdShown ? "To bank" : "To a bank\naccount"
                let title2 = kbdShown ? "To wallet" : "To another\nwallet"
                let disabled = centsToTransfer == 0    // TODO: check amountAvailable

                // Left button: To bank
                NavigationLink(destination: LazyView {
                    Text("Bank pressed")
                }) {
                    Text(title1)
                }
                .buttonStyle(TalerButtonStyle(type: .bordered))
                .disabled(disabled)

                NavigationLink(destination: LazyView {
                    SendPurpose(amountAvailable: amountAvailable,
                                    centsToSend: centsToTransfer,
                                        purpose: $purpose,
                                     expireDays: $expireDays,
                               deactivateAction: {})
                    .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
                }) {
                    Text(title2)
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(navTitle)
        .padding(.horizontal)
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setSheetID(SHEET_PAY_P2P)
            print("❗️Yikes SendAmount onAppear")
        }
        .onDisappear {
            print("❗️Yikes SendAmount onDisappear")
        }
    }
}
// MARK: -
#if DEBUG
struct SendAmount_Previews: PreviewProvider {
    static var previews: some View {
        let amount = Amount(currency: "TaLeR", integer: 10, fraction: 0)
        SendAmount(amountAvailable: amount)
    }
}
#endif
