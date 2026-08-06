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

// Called from DepositAmountV
struct DepositAmountView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balance: Balance?
    @Binding var balanceIndex: Int
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    let amountAvailable: Amount
    let paytoUri: String?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var checkDepositResult: CheckDepositResponse? = nil
    @State private var insufficient = false
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var depositStarted = false
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

    @MainActor
    private func startDeposit(_ scope: ScopeInfo) {
        if let paytoUri {
            depositStarted = true    // don't run twice
            Task {
                symLog.log("Deposit")
                if let result = try? await model.createDepositGroup(paytoUri,
                                                             scope: scope,
                                                            amount: amountToTransfer) {
                    symLog.log(result.transactionId)
                    if let txState = result.txState {
                        if txState.isKYC || txState.isKYCauth {
                            symLog.log("Deposit KYC")

                        } else {
//                          ViewState2.shared.popToRootView(stack.push())
                            NotificationCenter.default.post(name: .TransactionDone, object: nil, userInfo: nil)
                            dismissTop(stack.push())
                        }
                    }
                } else {
                    depositStarted = false
                }
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if depositStarted {
            let message = String(localized: "Depositing...", comment: "loading")
            LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
                .safeAreaInset(edge: .bottom) {
                    let buttonTitle = String(localized: "Abort", comment: "deposit")
                    Button(buttonTitle) { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
        } else { ScrollView {
            if let balance {
                let scopeInfo = balance.scopeInfo
                let availableStr = amountAvailable.formatted(scopeInfo, isNegative: false)

                let currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
//                let amountVoiceOver = amountToTransfer.formatted(scopeInfo, isNegative: false)
                let insufficientLabel = String(localized: "You don't have enough \(currencyInfo.specs.name).")
//                let insufficientLabel2 = String(localized: "but you only have \(available) to deposit.")

                let disabled = insufficient || amountToTransfer.isZero

                Text("Available: \(availableStr.0)")
                    .accessibilityLabel(Text("Available: \(availableStr.1)", comment: "a11y"))
                    .talerFont(.title3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
//                    .padding(.bottom, 2)
                let a11yLabel = String(localized: "Amount to deposit:", comment: "a11y, no abbreviations")
                let amountLabel = minimalistic ? String(localized: "Amount:")
                                               : a11yLabel
                CurrencyInputView(scope: scopeInfo,
                                 amount: $amountToTransfer,
                         amountLastUsed: amountLastUsed,
                              available: amountAvailable,       // enable shortcuts if available >= value
                                  title: amountLabel,
                              a11yTitle: a11yLabel,
                         shortcutAction: nil)
                    .padding(.horizontal)

                Text(insufficient ? insufficientLabel
                                  : feeLabel(feeStr))
                    .talerFont(.body)
                    .foregroundColor(insufficient ? WalletColors().attention
                                                  : (feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
                                                                                : WalletColors().negative)
                    .padding(4)
                let hint = String(localized: "enabled when amount is non-zero, but not higher than your available amount",
                                    comment: "a11y")
                Button(buttonTitle(amountToTransfer)) { startDeposit(balance.scopeInfo) }   // TODO: use exchange scope
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled || depositStarted))
                .disabled(disabled || depositStarted)
                .accessibilityHint(disabled ? hint : EMPTYSTRING)
                .padding(.horizontal)
            } else {    // no balance - Yikes
                Text("No balance. There seems to be a problem with the database...")
            }
        }
//        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_DEPOSIT, stack: stack.push())
            symLog.log("❗️ onAppear")
        }
        .onDisappear {
            symLog.log("❗️ onDisappear")
        }

//            .task(id: amountToTransfer.value) {
//                if let amountAvailable {
//                    do {
//                        insufficient = try amountToTransfer > amountAvailable
//                    } catch {
//                        print("Yikes❗️ insufficient failed❗️")
//                        insufficient = true
//                    }
//
//                    if insufficient {
//                        announce("\(amountVoiceOver), \(insufficientLabel2)")
//                        feeStr = EMPTYSTRING
//                    }
//                }
//                if !insufficient {
//                    if amountToTransfer.isZero {
//                        feeStr = EMPTYSTRING
//                        checkDepositResult = nil
//                    } else if let paytoUri {
//                        if let ppCheck = try? await model.checkDepositM(paytoUri, amount: amountToTransfer) {
//                            if let feeAmount = fee(ppCheck: ppCheck) {
//                                feeStr = feeAmount.formatted(scopeInfo, isNegative: false)
//                                let feeLabel = feeLabel(feeStr)
//                                announce("\(amountVoiceOver), \(feeLabel)")
//                            } else {
//                                feeStr = EMPTYSTRING
//                                announce(amountVoiceOver)
//                            }
//                            checkDepositResult = ppCheck
//                        } else {
//                            checkDepositResult = nil
//                        }
//                    }
//                }
//            }
        } // else
    } // body
}
// MARK: -
#if DEBUG
#endif
