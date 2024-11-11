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

// Called when tapping [􁾩Deposit]
struct DepositIbanV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var amountLastUsed: Amount

//    let amountAvailable: Amount?
//    @Binding var depositIBAN: String
//    @Binding var accountHolder: String

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
    @State private var currencyName: String = UNKNOWN
    @State private var currencySymbol: String = UNKNOWN
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used

    private func buttonTitle(_ amount: Amount) -> String {
//        let amountWithCurrency = amount.formatted(currencyInfo, isNegative: true, useISO: true)
        return String(localized: "Next", comment: "advance Deposit to Amount")
//        return String(localized: "Deposit \(amountWithCurrency)", comment: "amount with currency")
    }

    private var subjectTitle: String {
        return String(localized: "NavTitle_Deposit_AmountStr",
                   defaultValue: "Deposit IBAN",
                        comment: "NavTitle: Deposit")
    }

    @MainActor
    private func validateIban() async {
        if (try? await model.validateIban(depositIBAN)) == true {
            let payto = "payto://iban/\(depositIBAN)?receiver-name=\(accountHolder)"
            paytoUri = payto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        } else {
            paytoUri = nil
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the #
#endif
        let destination = DepositAmountV(stack: stack.push(),
                               selectedBalance: $selectedBalance,
                                amountLastUsed: $amountLastUsed,
                                      paytoUri: paytoUri)
        ScrollView { VStack (alignment: .leading, spacing: 6) {
            if !minimalistic {
                Text("Account holder:")
                    .talerFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
//                    .padding(.top)
            }
            TextField(minimalistic ? "Account holder" : EMPTYSTRING, text: $accountHolder)
                .focused($isFocused)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
//                .padding(minimalistic ? .bottom : .vertical)
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
//                    .padding(.top)
            }
            TextField(minimalistic ? "IBAN" : EMPTYSTRING, text: $depositIBAN)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
//                .padding(minimalistic ? .bottom : .vertical)

            let disabled = (accountHolder.count < 1) || paytoUri == nil    // TODO: check amountAvailable
            NavigationLink(destination: destination) {
                Text(buttonTitle(amountToTransfer))
            }
            .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
                .accessibilityHint(disabled ? String(localized: "enabled when account holder and IBAN are set") : EMPTYSTRING)
        }.padding(.horizontal) } // ScrollVStack
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .navigationTitle(subjectTitle)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_DEPOSIT_ACCEPT, stack: stack.push())
//            print("❗️ P2PSubjectV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PSubjectV onDisappear")
        }
        .task(id: depositIBAN) { await validateIban() }
    }
}
// MARK: -
#if DEBUG
#endif
