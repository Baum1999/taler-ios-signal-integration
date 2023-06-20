/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called by the user tapping "Send Coins" in the balances list
struct SendAmount: View {
    private let symLog = SymLogV()

    let model: Peer2peerModel?
    let amountAvailable: Amount
    @Binding var centsToTransfer: UInt64
    @Binding var purpose: String

    @State var peerPushCheck: CheckPeerPushDebitResponse?
    @State private var expireDays: UInt = 0

    private func fee(ppCheck: CheckPeerPushDebitResponse?) -> String {
        do {
            if let ppCheck {
                // Outgoing: fee = effective - raw
                let fee = try ppCheck.amountEffective - ppCheck.amountRaw
                return fee.readableDescription
            }
        } catch {}
        return ""
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountAvailable.currencyStr
        let navTitle = String(localized: "Send \(currency)")
        let currencyField = CurrencyField(value: $centsToTransfer, currency: currency)

        let fee = fee(ppCheck: peerPushCheck)
        ScrollView {
            let available = amountAvailable.readableDescription
            Text("Available: \(available)")
                .font(.title3)
            CurrencyInputView(currencyField: currencyField,
                              title: String(localized: "Amount to send:"))

            Text("+ \(fee) payment fee")
                .foregroundColor(.red)
                .padding(4)

            HStack {
                let disabled = centsToTransfer == 0    // TODO: check amountAvailable

                NavigationLink(destination: LazyView {
                    SendPurpose(model: model,
                      amountAvailable: amountAvailable,
                          centsToSend: centsToTransfer,
                                  fee: fee,
                              purpose: $purpose,
                           expireDays: $expireDays,
                     deactivateAction: {})
                }) {
                    Text("To another wallet")
                }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setViewID(VIEW_SEND_P2P)
            symLog.log("❗️Yikes SendAmount onAppear")
        }
        .onDisappear {
            symLog.log("❗️Yikes SendAmount onDisappear")
        }
        .task(id: centsToTransfer) {
            let amount = Amount.amountFromCents(currency, centsToTransfer)
            do {
                if let model {
                    let ppCheck = try await model.checkPeerPushDebitM(amount)
                    peerPushCheck = ppCheck
                    // TODO: set from exchange
                    //                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPushCheck = nil
            }
        }
    }
}
// MARK: -
#if DEBUG
struct SendAmount_Container : View {
    @State private var centsToTransfer: UInt64 = 510
    @State private var purpose: String = ""

    var body: some View {
        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
        SendAmount(model: nil,
         amountAvailable: amount,
         centsToTransfer: $centsToTransfer,
                 purpose: $purpose)
    }
}

struct SendAmount_Previews: PreviewProvider {
    static var previews: some View {
        SendAmount_Container()
    }
}
#endif
