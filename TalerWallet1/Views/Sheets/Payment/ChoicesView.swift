/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct ChoicesView: View, Sendable {
    let stack: CallStack
    let choiceTriple: [ChoiceTriple]
    let showHeader: Bool
    let automaticIndex: Int?
    @Binding var selectedChoice: Int

    @ViewBuilder
    func selectedBackground(_ useColor: Bool) -> some View {
        let is26: Bool = if #available(iOS 26.0, *) { true } else { false }
        let color: Color = useColor ? WalletColors().primaryAccent
                                    : .secondary
        if #available(iOS 17.0, *) {
            RoundedRectangle(cornerRadius: is26 ? 26 : 10)
                .fill(.background)
                .strokeBorder(color, lineWidth: 2.4)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color, lineWidth: 2.4)
                .foregroundColor(Color.clear)
        }
    }
    func description(_ contractChoice: ContractChoice) -> String? {
        if let i18nDict = contractChoice.descriptionI18n {
            if !i18nDict.isEmpty {
                for code in Locale.preferredLanguageCodes {
                    if let descI18n = i18nDict[code] {
                        return descI18n
                    }
                }
            }
        }
        if let desc = contractChoice.description {
            return desc
        }
        return nil
    }

    var body: some View {
        ForEach(choiceTriple, id: \.1) { choice in
            let selectionDetail: ChoiceSelectionDetail = choice.0
            let contractChoice: ContractChoice = choice.1
            let index: Int = choice.2
            let isPaymentPossible = selectionDetail.status == .paymentPossible
            let payAutomatic = automaticIndex == index
            let scopeInfo = selectionDetail.scopeInfo
            let amount = selectionDetail.amountRaw
            /// If it contains money, always show it. Disable but don’t hide it if insufficient - that serves as advertisement what you could buy if you had more money / tokens.
            /// If it only contains tokens, and insufficient, then hide it. Most probably there is a money payment option to acquire those tokens, which is advertisement enough.
            /// Tokens only, paymentPossible. If automaticIndex, then also hide it (and auto-pay it). Otherwise show it, so the user can select it.
            if (!amount.isZero || isPaymentPossible) && !payAutomatic {
                Section {
                    let amountV = HStack {
                        Spacer()
                        AmountV(stack: stack.push(),
                                scope: scopeInfo,
                               amount: contractChoice.amount)
                            .foregroundColor(isPaymentPossible ? .primary : .secondary  )
                    } .overlay {
                        Color.primary.opacity(0.001)        // Color.clear doesn't accept taps!
                            .contentShape(.rect)
                            .onTapGesture {
                                selectedChoice = index
                            }
                    }
                    if index == selectedChoice {
                        amountV.listRowBackground (
                            selectedBackground(isPaymentPossible)
//                          .padding(.top, n == 1 ? 0 : -15)
//                          .padding(.bottom, n == 10 ? 0 : -15)
                        )
                    } else {
                        amountV
                    }
                } header: {
                    if showHeader {
                        if let description = description(contractChoice) {
                            Text(description)
                }   }   }
            }
        }
    }
}
