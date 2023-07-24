/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SendPurpose: View {
    private let symLog = SymLogV()
    @FocusState private var isFocused: Bool

    let amountAvailable: Amount
    let centsToTransfer: UInt64
    let fee: String
    @Binding var summary: String
    @Binding var expireDays: UInt
//    var deactivateAction: () -> Void

    let formatter = CurrencyFormatter.shared    // TODO: based on currency

    let buttonFont: Font = .title2
    private var label: String {
        let mag = pow(10, formatter.maximumFractionDigits)
        return formatter.string(for: Decimal(centsToTransfer) / mag) ?? ""
    }

    var body: some View {
        let amount = Amount.amountFromCents(amountAvailable.currencyStr, centsToTransfer)

        VStack (spacing: 6) {
            Text(amount.readableDescription)
            Text("+ \(fee) payment fee")
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 6) {
                Text("Purpose:")
                    .padding(.top)
                    .font(.title3)

                TextField("Purpose", text: $summary)
                    .font(.title)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .border(.primary)
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
                    .font(.title3)

                // TODO: compute max Expiration day from peerPushCheck to disable 30 (and even 7)
                SelectDays(selected: $expireDays, maxExpiration: 35)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0) || (summary.count < 1)    // TODO: check amountAvailable

                NavigationLink(destination: LazyView {
                    SendDone(amountToSend: amount,
                            amountToReceive: nil,
                            summary: summary, expireDays: expireDays)
                }) {
                    Text("Send \(label) \(amountAvailable.currencyStr) now", comment: "first is value, second currencyString")
                        .font(buttonFont)
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .navigationTitle("To another Wallet")
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_SEND_PURPOSE)
            print("❗️ SendPurpose onAppear")
        }
        .onDisappear {
            print("❗️ SendPurpose onDisappear")
//            deactivateAction()
        }
        .task {
            symLog.log(".task")
            do {

            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

}
// MARK: -
#if DEBUG
struct SendPurpose_Previews: PreviewProvider {
    static var previews: some View {
        @State var summary: String = ""
        @State var expireDays: UInt = 0
        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
        SendPurpose(amountAvailable: amount,
                    centsToTransfer: 543,
                                fee: "0,43",
                            summary: $summary,
                         expireDays: $expireDays)
//        { print("deactivateAction") }
    }
}
#endif
