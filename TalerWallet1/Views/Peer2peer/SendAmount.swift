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
    @State private var insufficient: Bool = false
    @State private var feeStr: String = EMPTYSTRING

    private func fee(ppCheck: CheckPeerPushDebitResponse?) -> Amount? {
        do {
            if let ppCheck {
                // Outgoing: fee = effective - raw
                let fee = try ppCheck.amountEffective - ppCheck.amountRaw
                return fee
            }
        } catch {}
        return nil
    }
    
    var feeLabel: String { feeStr.count > 0 ? String(localized: "+ \(feeStr) send fee") : EMPTYSTRING }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountToTransfer.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let currencySymbol = currencyInfo.specs.altUnitNames?[0] ?? currency
        let navTitle = String(localized: "NavTitle_Send_Currency",
                           defaultValue: "Send \(currencySymbol)",
                                comment: "NavTitle: Send 'currencySymbol'")
        let amountStr = amountToTransfer.string(currencyInfo)
        let amountWithCurrency = amountToTransfer.string(currencyInfo, useSymbol: false)
        let buttonTitle = String(localized: "Send \(amountWithCurrency) now", comment: "amount with currency")
        let navTitle2 = String(localized: "NavTitle_Send_AmountStr",
                            defaultValue: "Send \(amountStr)",
                                 comment: "NavTitle: Send 'amountStr'")

        let available = amountAvailable.string(currencyInfo)
        let _ = symLog.log("currency: \(currency), available: \(available)")
        let amountVoiceOver = amountToTransfer.string(currencyInfo)
        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let insufficientLabel2 = String(localized: "but you only have \(available) to send.")

        ScrollView { VStack(alignment: .trailing) {
//          let _ = print("available: \(available)")
            Text("Available:\t\(available)")
                .accessibilityFont(.title3)
                .padding(.bottom, 2)
            CurrencyInputView(amount: $amountToTransfer,
                           available: amountAvailable,
                               title: iconOnly ? String(localized: "How much:")
                                               : String(localized: "Amount to send:"))
            let disabled = insufficient || amountToTransfer.isZero
            Text(insufficient ? insufficientLabel
                              : feeLabel)
                .accessibilityFont(.body)
                .foregroundColor(.red)
                .padding(4)

            NavigationLink(destination: LazyView {
                SendPurpose(stack: stack.push(),
                     amountToSend: amountToTransfer,
                  amountToReceive: nil,
                         navTitle: navTitle2,
                      buttonTitle: buttonTitle,
                         feeLabel: feeLabel,
                     currencyInfo: currencyInfo,
                          summary: $summary,
                       expireDays: $expireDays)
            }) { Text("Next") }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
//            Spacer()
        } } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_SEND_P2P, stack: stack.push())
            symLog.log("❗️Yikes SendAmount onAppear")
        }
        .onDisappear {
            symLog.log("❗️Yikes SendAmount onDisappear")
        }
        .task(id: amountToTransfer.value) {
            do {
                insufficient = try amountToTransfer > amountAvailable
                print("amountStr: \(amountVoiceOver)")
            } catch {
                print("Yikes❗️ insufficient failed❗️")
                insufficient = true
            }

            if insufficient {
                announce(this: "\(amountVoiceOver), \(insufficientLabel2)")
            } else if amountToTransfer.isZero {
                feeStr = EMPTYSTRING
            } else {
                do {
                    let ppCheck = try await model.checkPeerPushDebitM(amountToTransfer)
                    peerPushCheck = ppCheck
                // TODO: set from exchange
//                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
                    if let feeAmount = fee(ppCheck: peerPushCheck) {
                        feeStr = feeAmount.string(currencyInfo)
                    } else { feeStr = EMPTYSTRING }
                    announce(this: "\(amountVoiceOver), \(feeLabel)")
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
fileprivate struct Preview_Content: View {
    @State private var amountToTransfer = Amount(currency: TESTCURRENCY, cent: 510)
    @State private var summary: String = ""

    var body: some View {
        let amount = Amount(currency: TESTCURRENCY, integer: 10, fraction: 0)
        SendAmount(stack: CallStack("Preview"),
         amountAvailable: amount,
        amountToTransfer: $amountToTransfer,
                 summary: $summary)
    }
}

fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @StateObject private var controller = Controller.shared
        var body: some View {
            Preview_Content()
                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
