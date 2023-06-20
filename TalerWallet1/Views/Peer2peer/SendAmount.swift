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
    let model = Peer2peerModel.model()
    @State var peerPushCheck: CheckPeerPushDebitResponse?

    let amountAvailable: Amount
    let buttonFont: Font = .title2

    @State private var centsToTransfer: UInt64 = 0
    @State private var purpose: String = ""
    @State private var expireDays: UInt = 0

    private func fee(ppCheck: CheckPeerPushDebitResponse?) -> String {
        do {
            if let p2pcheck = ppCheck {
                let fee = try p2pcheck.amountEffective - p2pcheck.amountRaw
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
            Text("Choose where to send to:")
                .padding(.top)
                .font(.title3)
            HStack {
                let kbdShown: Bool = false  // keyboardResponder.keyboardHeight > 0
                let title2 = kbdShown ? "To wallet" : "To another\nwallet"
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
            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_SEND_P2P)
            print("❗️Yikes SendAmount onAppear")
        }
        .onDisappear {
            print("❗️Yikes SendAmount onDisappear")
        }
        .task(id: centsToTransfer) {
            let amount = Amount.amountFromCents(currency, centsToTransfer)
            do {
                peerPushCheck = try await model.checkPeerPushDebitM(amount)
                // TODO: set from exchange
//                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                peerPushCheck = nil
            }
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
