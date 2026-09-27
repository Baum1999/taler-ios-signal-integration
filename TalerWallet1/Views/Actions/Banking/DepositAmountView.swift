/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called from DepositAmountAction
struct DepositAmountView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balance: Balance?
    @Binding var balanceIndex: Int
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    let amountAvailable: Amount
    let depositStarted: Bool
    let action: () -> Void

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var checkDepositResult: CheckDepositResponse? = nil
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var exchange: Exchange? = nil                                // wg. noFees

    public static func navTitle(_ currency: String = EMPTYSTRING,
                               _ condition: Bool = false
    ) -> String {
        condition ? String(localized: "NavTitle_Deposit_Currency",
                        defaultValue: "Deposit \(currency)",
                             comment: "currencySymbol")
                  : String(localized: "NavTitle_Deposit",
                        defaultValue: "Deposit")
    }

    private func feeLabel(_ feeString: String) -> String {
        feeString.isEmpty ? EMPTYSTRING : String(localized: "+ \(feeString) fee")
    }

    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.noFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return checkDepositResult == nil ? false
                                         : true // TODO: !(feeAmount?.isZero ?? false)
    }

    @MainActor
    private func computeFeeDeposit(_ amount: Amount) async -> ComputeFeeResult? {
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        let insufficient = (try? amount > amountAvailable) ?? true
        if insufficient {
            return ComputeFeeResult.insufficient()
        }
//    private func fee(ppCheck: CheckDepositResponse?) -> Amount? {
        do {
//            if let ppCheck {
//                // Outgoing: fee = effective - raw
//                feeAmount = try ppCheck.fees.coin + ppCheck.fees.wire + ppCheck.fees.refresh
//                return feeAmount
//            }
        } catch {

        }
        return nil
    }

    private func buttonTitle(_ amount: Amount) -> String {
        if let balance {
            let amountWithCurrency = amount.formatted(balance.scopeInfo, isNegative: false, useISO: true)
            return DepositAmountView.navTitle(amountWithCurrency.0, true)
        }
        return DepositAmountView.navTitle()             // should never happen
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let balance {
            let scopeInfo = balance.scopeInfo
            let availableStr = amountAvailable.formatted(scopeInfo, isNegative: false)

            let currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
//          let amountVoiceOver = amountToTransfer.formatted(scopeInfo, isNegative: false)
            let insufficientLabel = String(localized: "You don't have enough \(currencyInfo.specs.name).")
//          let insufficientLabel2 = String(localized: "but you only have \(available) to deposit.")

            // amountAvailable is wallet-core's getMaxDepositAmount() verdict for this scope.
            // Fail closed when the two amounts cannot be compared - this happens while the
            // scope (and thus the currency) is being switched.
            let insufficient = !amountToTransfer.isZero
                            && ((try? amountToTransfer > amountAvailable) ?? true)
            let disabled = insufficient || amountToTransfer.isZero

            Text("Available: \(availableStr.0)")
                .accessibilityLabel(Text("Available: \(availableStr.1)", comment: "a11y"))
                .talerFont(.title3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
//              .padding(.bottom, 2)
            let a11yLabel = String(localized: "Amount to deposit:", comment: "a11y, no abbreviations")
            let amountLabel = minimalistic ? String(localized: "Amount:")
                                           : a11yLabel
            CurrencyInputView(scope: scopeInfo,
                             amount: $amountToTransfer,
                     amountLastUsed: amountLastUsed,
                          available: amountAvailable,       // enable shortcuts if available >= value
                       insufficient: false,                 // TODO: insufficient
                              title: amountLabel,
                          a11yTitle: a11yLabel,
                     shortcutAction: nil)
                .padding(.horizontal)
            Text(insufficient ? insufficientLabel
                              : feeLabel(feeStr))
                .talerFont(.body)
                .foregroundColor(insufficient ? WalletColors().attention
                                              : (feeAmount?.isZero ?? true) ? WalletColors().secondary2(colorScheme, colorSchemeContrast)
                                                                            : WalletColors().negative)
                .padding(4)
            let hint = String(localized: "enabled when amount is non-zero, but not higher than your available amount",
                                comment: "a11y")
            Button(buttonTitle(amountToTransfer)) { action() }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled || depositStarted))
                .disabled(disabled || depositStarted)
                .accessibilityHint(disabled ? hint : EMPTYSTRING)
                .padding(.horizontal)
        } else {    // no balance - Yikes
            Text("No balance. There seems to be a problem with the database...")
        }
    } // body
}
