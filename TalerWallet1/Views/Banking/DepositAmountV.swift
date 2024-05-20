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
    let paytoUri: String?
    let amountAvailable: Amount?
//    @Binding var depositIBAN: String
//    @Binding var accountHolder: String
    @Binding var amountToTransfer: Amount
//    let scopeInfo: ScopeInfo

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var prepareDepositResult: PrepareDepositResult? = nil
    @State private var insufficient = false
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var depositStarted = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var exchange: Exchange? = nil                                // wg. noFees

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

    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.noFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return prepareDepositResult != nil ? (!(feeAmount?.isZero ?? false))
                                    : false
    }

    private func buttonTitle(_ amount: Amount, _ currencyInfo: CurrencyInfo) -> String {
        let amountWithCurrency = amount.string(currencyInfo, useSymbol: false)
        return String(localized: "Deposit \(amountWithCurrency)", comment: "amount with currency")
    }

    private func subjectTitle(_ amount: Amount, _ currencyInfo: CurrencyInfo) -> String {
        let amountStr = amount.string(currencyInfo)
        return String(localized: "NavTitle_Deposit_AmountStr",
                      defaultValue: "Deposit", comment: "NavTitle: Deposit")
        //                   defaultValue: "Deposit \(amountStr)", comment: "NavTitle: Deposit 'amountStr'")
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if depositStarted {
            LoadingView(scopeInfo: nil, message: "Depositing...")
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss

//            ViewState2.shared.popToRootView

        } else {
            let currency = amountToTransfer.currencyStr
            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
            let currencySymbol = currencyInfo.specs.altUnitNames?[0] ?? currency
            let navTitle = String(localized: "NavTitle_Deposit_Currency",
                                  defaultValue: "Deposit \(currencySymbol)",
                                  comment: "NavTitle: Deposit 'currencySymbol'")
            let available = amountAvailable?.string(currencyInfo) ?? "an unknown amount"
            let _ = print("available: \(available)")
            let _ = symLog.log("currency: \(currency), available: \(available)")
            let amountVoiceOver = amountToTransfer.string(currencyInfo)
            let insufficientLabel = String(localized: "You don't have enough \(currency).")
            let insufficientLabel2 = String(localized: "but you only have \(available) to deposit.")

            let disabled = insufficient || amountToTransfer.isZero
            ScrollView { VStack(alignment: .trailing) {
//                Text("via \(exchange.exchangeBaseUrl.trimURL())")
//                    .multilineTextAlignment(.center)
//                    .talerFont(.body)

                Text("Available:\t\(available)")
                    .talerFont(.title3)
                    .padding(.bottom, 2)
                CurrencyInputView(amount: $amountToTransfer,
                               available: nil,  // amountAvailable,
                                   title: minimalistic ? String(localized: "Amount:")
                                                       : String(localized: "Amount to deposit:"),
                          shortcutAction: nil)
//                .padding(.top)
                Text(insufficient ? insufficientLabel
                                  : feeLabel)
                    .talerFont(.body)
                    .foregroundColor(insufficient ? .red
                                                  : (feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
                                                                                : .red)
                    .padding(4)
                Button(buttonTitle(amountToTransfer, currencyInfo)) {
                    if let paytoUri {
                        depositStarted = true    // don't run twice
                        Task { // runs on MainActor
                            symLog.log("Deposit")
                            if let result = try? await model.createDepositGroupM(paytoUri, amount: amountToTransfer) {
                                symLog.log(result.transactionId)
                                ViewState2.shared.popToRootView(stack.push())
                                NotificationCenter.default.post(name: .TransactionDone, object: nil, userInfo: nil)
                            } else {
                                depositStarted = false
                            }
                        }
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled || depositStarted))
                .disabled(disabled || depositStarted)
                .accessibilityHint(disabled ? String(localized: "enabled when amount is non-zero, but not higher than your available amount") : EMPTYSTRING)
            }.padding(.horizontal) } // ScrollVStack
            .frame(maxWidth: .infinity, alignment: .leading)
//            .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .navigationTitle(navTitle)
            .onAppear {
                DebugViewC.shared.setViewID(VIEW_DEPOSIT, stack: stack.push())
                symLog.log("❗️ \(navTitle) onAppear")
            }
            .onDisappear {
                symLog.log("❗️ \(navTitle) onDisappear")
            }
            .task(id: amountToTransfer.value) {
                if let amountAvailable {
                    do {
                        insufficient = try amountToTransfer > amountAvailable
                    } catch {
                        print("Yikes❗️ insufficient failed❗️")
                        insufficient = true
                    }

                    if insufficient {
                        announce("\(amountVoiceOver), \(insufficientLabel2)")
                        feeStr = EMPTYSTRING
                    }
                }
                if !insufficient {
                    if amountToTransfer.isZero {
                        feeStr = EMPTYSTRING
                        prepareDepositResult = nil
                    } else if let paytoUri {
                        if let ppCheck = try? await model.prepareDepositM(paytoUri, amount: amountToTransfer) {
                            prepareDepositResult = ppCheck
                            if let feeAmount = fee(ppCheck: prepareDepositResult) {
                                feeStr = feeAmount.string(currencyInfo)
                            } else { feeStr = EMPTYSTRING }
                            announce("\(amountVoiceOver), \(feeLabel)")
                        } else {
                            prepareDepositResult = nil
                        }
                    }
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
#endif
