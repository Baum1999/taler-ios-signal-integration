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
    let scopeInfo: ScopeInfo

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var peerPushCheck: CheckPeerPushDebitResponse? = nil
    @State private var expireDays = SEVENDAYS
    @State private var insufficient = false
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var shortcutSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var exchange: Exchange? = nil          // wg. hasNoFees

    private func fee(ppCheck: CheckPeerPushDebitResponse?) -> Amount? {
        do {
            if let ppCheck {
                // Outgoing: fee = effective - raw
                feeAmount = try ppCheck.amountEffective - ppCheck.amountRaw
                return feeAmount
            }
        } catch {}
        feeAmount = nil
        return feeAmount
    }
    
    var feeLabel: String { feeStr.count > 0 ? String(localized: "+ \(feeStr) fee") : EMPTYSTRING }

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() {
        buttonSelected = true
    }
    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.hasNoFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return peerPushCheck != nil ? (!(feeAmount?.isZero ?? false))
                                    : false
    }

    var body: some View {
#if PRINT_CHANGES
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
        let insufficientLabel2 = String(localized: "but you only have \(available) to send.")

        let inputDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: feeLabel,
                 feeIsNotZero: feeIsNotZero(),
                 currencyInfo: currencyInfo,
                 amountToSend: true,
             amountToTransfer: $amountToTransfer,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        let shortcutDestination = LazyView {
            P2PSubjectV(stack: stack.push(),
                     feeLabel: nil,
                 feeIsNotZero: feeIsNotZero(),
                 currencyInfo: currencyInfo,
                 amountToSend: true,
             amountToTransfer: $amountShortcut,
                      summary: $summary,
                   expireDays: $expireDays)
        }
        ScrollView {
            AmountInputV(stack: stack.push(), url: nil,
               amountAvailable: amountAvailable,
              amountToTransfer: $amountToTransfer,
                   amountLabel: minimalistic ? String(localized: "Amount:")
                                             : String(localized: "Amount to send:"),
                  wantsSummary: true,
                       summary: $summary,
                  insufficient: $insufficient,
                     feeAmount: $feeAmount,
                shortcutAction: shortcutAction,
                  buttonAction: buttonAction)
            .background(NavigationLink(destination: shortcutDestination, isActive: $shortcutSelected)
                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
            )
            .background(NavigationLink(destination: inputDestination, isActive: $buttonSelected)
                        { EmptyView() }.frame(width: 0).opacity(0).hidden()
            )
        } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
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
            if exchange == nil {
                if let url = scopeInfo.url {
                    do {
                        exchange = try await model.getExchangeByUrl(url: url)
                    } catch {
                        symLog.log(error.localizedDescription)
                        model.showError(.error(error))
                        controller.playSound(0)
                    }
                }
            }
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
    @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 510)
    @State private var summary: String = ""

    var body: some View {
        let amount = Amount(currency: LONGCURRENCY, cent: 1000)
        let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                       scopeInfo: scopeInfo,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        SendAmount(stack: CallStack("Preview"),
         amountAvailable: amount,
        amountToTransfer: $amountToPreview,
                   summary: $summary, scopeInfo: scopeInfo)
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
