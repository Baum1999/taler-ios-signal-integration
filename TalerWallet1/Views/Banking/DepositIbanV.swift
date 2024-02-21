/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog


struct DepositIbanV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let feeLabel: String?
    let feeIsNotZero: Bool?            // nil = no fees at all, false = no fee for this tx
    let amountAvailable: Amount?
//    @Binding var depositIBAN: String
//    @Binding var accountHolder: String
    @Binding var amountToTransfer: Amount

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("depositIBAN") var depositIBAN: String = EMPTYSTRING
    @AppStorage("accountHolder") var accountHolder: String = EMPTYSTRING

    @State private var myFeeLabel: String = EMPTYSTRING
    @State private var transactionStarted: Bool = false
    @State private var paytoUri: String? = nil
    @FocusState private var isFocused: Bool

    private func buttonTitle(_ amount: Amount, _ currencyInfo: CurrencyInfo) -> String {
        let amountWithCurrency = amount.string(currencyInfo, useSymbol: false)
        return String(localized: "Next", comment: "advance Deposit to Amount")
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
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = amountToTransfer.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let destination = LazyView {
            DepositAmountV(stack: stack.push(),
                        paytoUri: paytoUri,
//                 exchangeBaseUrl: baseURL,
                 amountAvailable: amountAvailable,
//                     depositIBAN: $depositIBAN,
//                   accountHolder: $accountHolder,
                amountToTransfer: $amountToTransfer)
        }
        ScrollView { VStack (alignment: .leading, spacing: 6) {
            if let feeIsNotZero {       // don't show fee if nil
                let label = feeLabel ?? myFeeLabel
                if label.count > 0 {
                    Text(label)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(feeIsNotZero ? .red 
                                                      : WalletColors().secondary(colorScheme, colorSchemeContrast))
                        .talerFont(.body)
                }
            }
            if !minimalistic {
                Text("Account holder:")
                    .talerFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
                    .padding(.top)
            }
            TextField(minimalistic ? "Account holder" : EMPTYSTRING, text: $accountHolder)
                .focused($isFocused)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
                .padding(minimalistic ? .bottom : .vertical)
                .onAppear {
                    if !UIAccessibility.isVoiceOverRunning {
                        symLog.log("dispatching kbd...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            isFocused = true        // make first responder - raise keybord
                            symLog.log("...kbd isFocused")
                        }
                    }
                }

            if !minimalistic {
                Text("IBAN:")
                    .talerFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
                    .padding(.top)
            }
            TextField(minimalistic ? "IBAN" : EMPTYSTRING, text: $depositIBAN)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
                .padding(minimalistic ? .bottom : .vertical)

            let disabled = (accountHolder.count < 1) || paytoUri == nil    // TODO: check amountAvailable
            NavigationLink(destination: destination) {
                Text(buttonTitle(amountToTransfer, currencyInfo))
            }
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
                .accessibilityHint(disabled ? "enabled when account holder and IBAN are set" : EMPTYSTRING)
        }.padding(.horizontal) } // ScrollVStack
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .navigationTitle(subjectTitle(amountToTransfer, currencyInfo))
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_DEPOSIT_ACCEPT, stack: stack.push())
//            print("❗️ P2PSubjectV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PSubjectV onDisappear")
        }
        .task(id: depositIBAN) {
            do {
                if try await model.validateIbanM(depositIBAN) {
                    let payto = "payto://iban/\(depositIBAN)?receiver-name=\(accountHolder)"
                    paytoUri = payto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                paytoUri = nil
            }
        }
    }
}
// MARK: -
#if DEBUG
#endif
