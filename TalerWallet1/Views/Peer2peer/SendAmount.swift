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
    @State private var expireDays = SEVENDAYS
    @State private var insufficient = false
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used

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

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        buttonSelected = true
    }

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
        let available = amountAvailable.string(currencyInfo)
//        let _ = print("available: \(available)")
        let _ = symLog.log("currency: \(currency), available: \(available)")
        let amountVoiceOver = amountToTransfer.string(currencyInfo)
        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let insufficientLabel2 = String(localized: "but you only have \(available) to send.")

        let inputDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: feeLabel,
                 currencyInfo: currencyInfo,
                 amountToSend: true,
             amountToTransfer: $amountToTransfer,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let shortcutDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: nil,
                 currencyInfo: currencyInfo,
                 amountToSend: true,
             amountToTransfer: $amountShortcut,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let disabled = insufficient || amountToTransfer.isZero
        ScrollView { VStack(alignment: .trailing) {
            Text("Available:\t\(available)")
                .accessibilityFont(.title3)
                .padding(.bottom, 2)
            CurrencyInputView(amount: $amountToTransfer,
                           available: amountAvailable,
                               title: iconOnly ? String(localized: "How much:")
                                               : String(localized: "Amount to send:"),
                      shortcutAction: shortcutAction)
            Text(insufficient ? insufficientLabel
                              : feeLabel)
                .accessibilityFont(.body)
                .foregroundColor(.red)
                .padding(4)
            NavigationLink(destination: inputDestination) { Text("Next") }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .background(NavigationLink(destination: shortcutDestination, isActive: $buttonSelected)
                    { EmptyView() }.frame(width: 0).opacity(0).hidden()
                )
        } } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_SEND, stack: stack.push())
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
        .task(id: amountToTransfer.value) {
            do {
                insufficient = try amountToTransfer > amountAvailable
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
    @State private var amountToPreview = Amount(currency: TESTCURRENCY, cent: 510)
    @State private var summary: String = ""

    var body: some View {
        let amount = Amount(currency: TESTCURRENCY, integer: 10, fraction: 0)
        SendAmount(stack: CallStack("Preview"),
         amountAvailable: amount,
        amountToTransfer: $amountToPreview,
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
