/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct PaymentPurpose: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    let scopeInfo: ScopeInfo
    let centsToTransfer: UInt64
    let fee: String
    @Binding var summary: String
    @Binding var expireDays: UInt
//    var deactivateAction: () -> Void

    @FocusState private var isFocused: Bool

    let formatter = CurrencyFormatter.shared    // TODO: based on currency
//    let buttonFont: Font = .talerTitle2

    private var label: String {
        let mag = pow(10, formatter.maximumFractionDigits)
        return formatter.string(for: Decimal(centsToTransfer) / mag) ?? ""
    }

    var body: some View {
        let amount = Amount.amountFromCents(scopeInfo.currency, centsToTransfer)

        VStack (spacing: 6) {
            Text(amount.readableDescription)
            Text("+ \(fee) payment fee")
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 6) {
                Text("Purpose:")
                    .padding(.top)
                    .accessibilityFont(.title3)

                TextField("Purpose", text: $summary)
                    .accessibilityFont(.title)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isFocused = true        // make first responder - raise keybord
                        }
                    }

                HStack{
                    Spacer()
                    Text(verbatim: "\(summary.count)/100")
                } // maximum 100 characters

                Text("Expires in:")
                    .accessibilityFont(.title3)

                SelectDays(selected: $expireDays, maxExpiration: THIRTYDAYS)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0) || (summary.count < 1)

                NavigationLink(destination: LazyView {
                    SendDone(stack: stack.push(),
                      amountToSend: nil,
                   amountToReceive: amount,
                           summary: summary,
                        expireDays: expireDays)
                }) {
                    Text("Request \(label) \(scopeInfo.currency)")
//                        .accessibilityFont(buttonFont)
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .navigationTitle("Request")
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_RECEIVE_PURPOSE)
            print("❗️ PaymentPurpose onAppear")
        }
        .onDisappear {
            print("❗️ PaymentPurpose onDisappear")
//            deactivateAction()
        }
    }

}
// MARK: -
#if DEBUG
//struct PaymentPurpose_Previews: PreviewProvider {
//    static var previews: some View {
//        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
//        @State var summary: String = "pUrPoSe"
//        @State var expireDays: UInt = 0
//        PaymentPurpose(scopeInfo: scopeInfo,
//                 centsToTransfer: 5,
//                             fee: "fee",
//                         summary: $summary,
//                      expireDays: $expireDays)
//        { print("deactivateAction") }
//    }
//}
#endif
