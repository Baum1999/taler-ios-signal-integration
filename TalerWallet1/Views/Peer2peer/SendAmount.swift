/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping "Send Coins" in the balances list
struct SendAmount: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    let amountAvailable: Amount // TODO: GetMaxPeerPushAmount
    @Binding var amountToTransfer: Amount
    @Binding var summary: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("iconOnly") var iconOnly: Bool = false

    @State var peerPushCheck: CheckPeerPushDebitResponse? = nil
    @State private var expireDays: UInt = SEVENDAYS

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
        let navTitle = String(localized: "Send \(currency)", comment: "Send currency, Dialog Title")
        let fee = fee(ppCheck: peerPushCheck)
        ScrollView {
            VStack(alignment: .trailing) {
                let available = amountAvailable.readableDescription // TODO: formatter
                Text("Available: \(available)")
                    .accessibilityFont(.title3)
                    .padding(.bottom, 2)
                CurrencyInputView(amount: $amountToTransfer,
                                   title: iconOnly ? String(localized: "How much:")
                                                   : String(localized: "Amount to send:"),
                           shortcutLabel: String(localized: "Send", comment: "VoiceOver: Send $50,$25,$10,$5 shortcut buttons"))
                Text("+ \(fee) payment fee")
                    .accessibilityFont(.body)
                    .foregroundColor(.red)
                    .padding(4)

                let disabled = amountToTransfer.isZero    // TODO: check amountAvailable

                NavigationLink(destination: LazyView {
                    SendPurpose(stack: stack.push(),
                      amountAvailable: amountAvailable,
                     amountToTransfer: amountToTransfer,
                                  fee: fee,
                              summary: $summary,
                           expireDays: $expireDays)
                }) {
                    Text("Next")
                }   .buttonStyle(TalerButtonStyle(type: .prominent))
                    .disabled(disabled)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {   // make CurrencyField show the keyboard
            DebugViewC.shared.setViewID(VIEW_SEND_P2P, stack: stack.push())
            symLog.log("❗️Yikes SendAmount onAppear")
        }
        .onDisappear {
            symLog.log("❗️Yikes SendAmount onDisappear")
        }
        .task(id: amountToTransfer.value) {
            if !amountToTransfer.isZero {
                do {
                    let ppCheck = try await model.checkPeerPushDebitM(amountToTransfer)
                    peerPushCheck = ppCheck
                // TODO: set from exchange
//                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
                } catch {    // TODO: error
                    symLog.log(error.localizedDescription)
                    peerPushCheck = nil
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
struct SendAmount_Container : View {
    @State private var amountToTransfer = Amount(currency: DEMOCURRENCY, cent: 510)
    @State private var summary: String = ""

    var body: some View {
        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
        SendAmount(stack: CallStack("Preview"),
         amountAvailable: amount,
        amountToTransfer: $amountToTransfer,
                 summary: $summary)
    }
}

//struct SendAmount_Previews: PreviewProvider {
//    static var previews: some View {
//        SendAmount_Container()
//    }
//}
#endif
