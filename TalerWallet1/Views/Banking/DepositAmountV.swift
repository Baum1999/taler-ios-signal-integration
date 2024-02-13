/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Called when tapping "Deposit" in the exchanges list
struct DepositAmountV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

//    let exchangeBaseUrl: String
    let amountAvailable: Amount // TODO: GetMaxPeerPushAmount
    @Binding var amountToTransfer: Amount
    @Binding var depositIBAN: String
    @Binding var accountHolder: String
//    let scopeInfo: ScopeInfo

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var prepareDepositResult: PrepareDepositResult? = nil
    @State private var insufficient = false
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var exchange: Exchange? = nil          // wg. hasNoFees

    private func fee(ppCheck: PrepareDepositResult?) -> Amount? {
        do {
            if let ppCheck {
                // Outgoing: fee = effective - raw
                feeAmount = try ppCheck.fees.coin + ppCheck.fees.wire + ppCheck.fees.refresh
                return feeAmount
            }
        } catch {}
        feeAmount = nil
        return feeAmount
    }
    
    var feeLabel: String { feeStr.count > 0 ? String(localized: "+ \(feeStr) fee") : EMPTYSTRING }

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        buttonSelected = true
    }
    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.hasNoFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return prepareDepositResult != nil ? (!(feeAmount?.isZero ?? false))
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
        let navTitle = String(localized: "NavTitle_Deposit_Currency",
                           defaultValue: "Deposit \(currencySymbol)",
                                comment: "NavTitle: Deposit 'currencySymbol'")
        let available = amountAvailable.string(currencyInfo)
        let _ = print("available: \(available)")
        let _ = symLog.log("currency: \(currency), available: \(available)")
        let amountVoiceOver = amountToTransfer.string(currencyInfo)
        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let insufficientLabel2 = String(localized: "but you only have \(available) to send.")

        let inputDestination = LazyView {
            DepositIbanV(stack: stack.push(),
                     feeLabel: feeLabel,
                 feeIsNotZero: feeIsNotZero(),
                 currencyInfo: currencyInfo,
             amountToTransfer: $amountToTransfer,
                  depositIBAN: $depositIBAN,
                accountHolder: $accountHolder)
        }
        let shortcutDestination = LazyView {
            DepositIbanV(stack: stack.push(),
                     feeLabel: nil,
                 feeIsNotZero: feeIsNotZero(),
                 currencyInfo: currencyInfo,
             amountToTransfer: $amountShortcut,
                  depositIBAN: $depositIBAN,
                accountHolder: $accountHolder)
        }
        let disabled = insufficient || amountToTransfer.isZero
        ScrollView { VStack(alignment: .trailing) {
//            Text("Available:\t\(available)")
//                .talerFont(.title3)
//                .padding(.bottom, 2)
            CurrencyInputView(amount: $amountToTransfer,
                           available: nil,  // amountAvailable,
                               title: minimalistic ? String(localized: "Amount:")
                                                   : String(localized: "Amount to deposit:"),
                      shortcutAction: shortcutAction)
            Text(insufficient ? insufficientLabel
                              : feeLabel)
                .talerFont(.body)
                .foregroundColor(insufficient ? .red
                                 : (feeAmount?.isZero ?? true) ? .secondary : .red)
                .padding(4)
            NavigationLink(destination: inputDestination) { Text("Next") }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .background(NavigationLink(destination: shortcutDestination, isActive: $buttonSelected)
                    { EmptyView() }.frame(width: 0).opacity(0).hidden()
                )
        }.padding(.horizontal) } // ScrollVStack
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
//            do {
//                insufficient = try amountToTransfer > amountAvailable
//            } catch {
//                print("Yikes❗️ insufficient failed❗️")
//                insufficient = true
//            }

//            if insufficient {
//                announce(this: "\(amountVoiceOver), \(insufficientLabel2)")
//            } else if amountToTransfer.isZero {
//                feeStr = EMPTYSTRING
//            } else {
//                do {
//                    let ppCheck = try await model.prepareDepositM("", amount: amountToTransfer)
//                    prepareDepositResult = ppCheck
//                    if let feeAmount = fee(ppCheck: prepareDepositResult) {
//                        feeStr = feeAmount.string(currencyInfo)
//                    } else { feeStr = EMPTYSTRING }
//                    announce(this: "\(amountVoiceOver), \(feeLabel)")
//                } catch {    // TODO: error
//                    symLog.log(error.localizedDescription)
//                    prepareDepositResult = nil
//                }
//            }
        }
    }
}
// MARK: -
#if DEBUG
#endif
