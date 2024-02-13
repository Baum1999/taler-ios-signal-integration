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
    let currencyInfo: CurrencyInfo
    @Binding var amountToTransfer: Amount
    @Binding var depositIBAN: String
    @Binding var accountHolder: String

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var myFeeLabel: String = EMPTYSTRING
    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool

    private func buttonTitle(_ amount: Amount, _ currencyInfo: CurrencyInfo) -> String {
        let amountWithCurrency = amount.string(currencyInfo, useSymbol: false)
        return String(localized: "Deposit \(amountWithCurrency)", comment: "amount with currency")
    }

    private func subjectTitle(_ amount: Amount, _ currencyInfo: CurrencyInfo) -> String {
        let amountStr = amount.string(currencyInfo)
        return String(localized: "NavTitle_Deposit_AmountStr",
                   defaultValue: "Deposit \(amountStr)", comment: "NavTitle: Deposit 'amountStr'")
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ScrollView { VStack (alignment: .leading, spacing: 6) {
            if let feeIsNotZero {       // don't show fee if nil
                let label = feeLabel ?? myFeeLabel
                if label.count > 0 {
                    Text(label)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(feeIsNotZero ? .red : .secondary)
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
                .onAppear {
                    symLog.log("dispatching kbd...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        isFocused = true        // make first responder - raise keybord
                        symLog.log("...kbd isFocused")
                    }
                }

            if !minimalistic {
                Text("IBAN:")
                    .talerFont(.title3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRemoveTraits(.isStaticText)
                    .padding(.top)
            }
            TextField(minimalistic ? "Account holder" : EMPTYSTRING, text: $depositIBAN)
                .talerFont(.title2)
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)

            let disabled = (accountHolder.count < 1) || (depositIBAN.count < 1)    // TODO: check amountAvailable
            NavigationLink(destination: LazyView {
                EmptyView()
//                    P2PReadyV(stack: stack.push(),
//                            summary: summary,
//                         expireDays: expireDays,
//                       amountToSend: amountToSend,
//                   amountToTransfer: amountToTransfer,
//                 transactionStarted: $transactionStarted)
            }) {
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
//        .task(id: amountToTransfer.value) {
//            if amountToSend && feeLabel == nil {
//                do {
//                    let ppCheck = try await model.checkPeerPushDebitM(amountToTransfer)
//                    if let feeAmount = p2pFee(ppCheck: ppCheck) {
//                        let feeStr = feeAmount.string(currencyInfo)
//                        myFeeLabel = String(localized: "+ \(feeStr) fee")
//                    } else { myFeeLabel = EMPTYSTRING }
//                } catch {    // TODO: error
//                    symLog.log(error.localizedDescription)
//                }
//            }
//        }
    }
}
// MARK: -
#if DEBUG
#endif
