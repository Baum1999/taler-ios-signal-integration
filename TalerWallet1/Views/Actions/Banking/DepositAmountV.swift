/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called from DepositIbanV
struct DepositAmountV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var amountLastUsed: Amount
    let paytoUri: String?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // GetMaxPeerPushAmount

    @MainActor
    private func viewDidLoad() async {
        let balances = controller.balances
        if let selectedBalance {
            if selectedBalance.available.isZero {
                // find another balance
                balance = Balance.firstNonZero(balances)
            } else {
                balance = selectedBalance
            }
        } else {
            balance = Balance.firstNonZero(balances)
        }
        if let balance {
            balanceIndex = balances.firstIndex(of: balance) ?? 0
        } else {
            balanceIndex = 0
            balance = (balances.count > 0) ? balances[0] : nil
        }
    }

    @MainActor
    private func newBalance() async {
        symLog.log("❗️ task \(balanceIndex)")
        if let balance {
            let scopeInfo = balance.scopeInfo
            amountToTransfer.setCurrency(scopeInfo.currency)
            do {
                amountAvailable = try await model.getMaxDepositAmount(scopeInfo)
            } catch {
                // TODO: Error
                amountAvailable = balance.available
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        let count = controller.balances.count
        let _ = symLog.log("count = \(count)")
        let navTitle = String(localized: "NavTitle_Deposit_Currency",
                           defaultValue: "Deposit",     // \(currencySymbol)",
                                comment: "NavTitle: Deposit 'currencySymbol'")
        let scrollView = ScrollView {
            if count > 0 {
                ScopePicker(value: $balanceIndex,
                      onlyNonZero: true)
                { index in
                    balanceIndex = index
                    balance = controller.balances[index]
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            DepositAmountContent(stack: stack.push(),
                               balance: $balance,
                          balanceIndex: $balanceIndex,
                        amountLastUsed: $amountLastUsed,
                      amountToTransfer: $amountToTransfer,
                       amountAvailable: amountAvailable,
                              paytoUri: paytoUri)
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .onAppear {
                DebugViewC.shared.setViewID(VIEW_DEPOSIT, stack: stack.push())
                symLog.log("❗️ \(navTitle) onAppear")
            }
            .onDisappear {
                symLog.log("❗️ \(navTitle) onDisappear")
            }
            .task { await viewDidLoad() }
            .task(id: balanceIndex + (1000 * controller.currencyTicker)) { await newBalance() }

        if #available(iOS 16.0, *) {
            if #available(iOS 16.4, *) {
                scrollView.toolbar(.hidden, for: .tabBar)
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                scrollView.toolbar(.hidden, for: .tabBar)
            }
        } else {
            scrollView
        }
    }
}
// MARK: -
struct DepositAmountContent: View {
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

    private func feeLabel(_ feeString: String) -> String {
        feeString.count > 0 ? String(localized: "+ \(feeString) fee")
                            : EMPTYSTRING
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
            return String(localized: "Deposit \(amountWithCurrency)", comment: "Button: amount with currency")
        }
        return subjectTitle(amount)             // should never happen
    }

    private func subjectTitle(_ amount: Amount) -> String {
//        let amountStr = amount.formatted(scopeInfo, isNegative: false)
        return String(localized: "NavTitle_Deposit_AmountStr",
                      defaultValue: "Deposit", comment: "NavTitle: Deposit")
        //            defaultValue: "Deposit \(amountStr)", comment: "NavTitle: Deposit 'amountStr'")
    }

    @MainActor
    private func startDeposit() {
        if let paytoUri {
            depositStarted = true    // don't run twice
            Task {
                symLog.log("Deposit")
                if let result = try? await model.createDepositGroup(paytoUri, amount: amountToTransfer) {
                    symLog.log(result.transactionId)
                    ViewState2.shared.popToRootView(stack.push())
                    NotificationCenter.default.post(name: .TransactionDone, object: nil, userInfo: nil)
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
            LoadingView(scopeInfo: nil, message: "Depositing...")
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Done" button to dismiss
        } else { Group {
            if let balance {
                let scopeInfo = balance.scopeInfo
                let availableStr = amountAvailable.formatted(scopeInfo, isNegative: false)

                let currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
//                let amountVoiceOver = amountToTransfer.formatted(scopeInfo, isNegative: false)
                let insufficientLabel = String(localized: "You don't have enough \(currencyInfo.specs.name).")
//                let insufficientLabel2 = String(localized: "but you only have \(available) to deposit.")

            let disabled = insufficient || amountToTransfer.isZero

                Text("Available:\t\(availableStr)")
                    .talerFont(.title3)
                    .padding(.bottom, 2)
                CurrencyInputView(scope: scopeInfo,
                                 amount: $amountToTransfer,
                         amountLastUsed: amountLastUsed,
                              available: nil,  // amountAvailable,
                                  title: minimalistic ? String(localized: "Amount:")
                                                      : String(localized: "Amount to deposit:"),
                         shortcutAction: nil)

                Text(insufficient ? insufficientLabel
                                  : feeLabel(feeStr))
                    .talerFont(.body)
                    .foregroundColor(insufficient ? .red
                                                  : (feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
                                                                                : .red)
                    .padding(4)
                Button(buttonTitle(amountToTransfer)) { startDeposit() }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled || depositStarted))
                .disabled(disabled || depositStarted)
                .accessibilityHint(disabled ? String(localized: "enabled when amount is non-zero, but not higher than your available amount") : EMPTYSTRING)
            } else {    // no balance - Yikes
                Text("No balance. There seems to be a problem with the database...")
            }
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
