/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct SelectedBackground: View, Sendable {
    let useColor: Bool?

    var body: some View {
        let is26: Bool = if #available(iOS 26.0, *) { true } else { false }
        let rect = RoundedRectangle(cornerRadius: is26 ? 26 : 10)
        let line = useColor == nil ? 0.5 : 2.4
        let color = useColor == true ? WalletColors().primaryAccent
                  : useColor == false ? .secondary : WalletColors().gray4
        if #available(iOS 17.0, *) {
            rect
                .fill(.background)
                .strokeBorder(color, lineWidth: line)
        } else {
            rect
                .strokeBorder(color, lineWidth: line)
                .background(.background)
                .clipped()
                .clipShape(rect)
        }
    }
}
// MARK: -
struct TokenView: View, Sendable {
    let count: Int?
    let slug: String
    let tokenFamilies: [String: ContractTokenFamily]   // token_family_slug: String

    var body: some View {
        if let family = tokenFamilies[slug] {
            let accent = WalletColors().primaryAccent
            let onPrimary = WalletColors().onPrimary
            let isPass = family.details.clazz == "subscription" // else "discount"
            HStack {
                TokenLabel(title: family.name, isActive: true, isPass: isPass)
                Spacer()
                if let count {
                    Text("x\(count)")
                        .foregroundColor(onPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.3)))
                }
            }
            .talerFont(.headline)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.1)))
        }

    }
}
struct OutputTokenView: View, Sendable {
    let outputs: [ContractOutputAny]
    let tokenFamilies: [String: ContractTokenFamily]   // token_family_slug: String

    var body: some View {
        ForEach(outputs, id: \.self) { output in
            switch output {
                case .token(let token):
                    if let slug = token.tokenFamilySlug {
                        let count = token.count ?? 1
                        TokenView(count: count > 1 ? count : nil,
                                   slug: slug,
                          tokenFamilies: tokenFamilies)
                    }
                case .taxReceipt(let taxReceipt):
                    let amount = taxReceipt.amount
                    // TODO: taxReceipt
                case .unknown(let string):
                    let _ = print("❗️❗️ChoicesView: Unknown output type: \(string)")
            }
        }
    }
}
struct InputTokenView: View, Sendable {
    let inputs: [ContractInput]
    let tokenFamilies: [String: ContractTokenFamily]   // token_family_slug: String

    var body: some View {
        ForEach(inputs, id: \.self) { input in
            if let slug = input.tokenFamilySlug {
                let count = input.count ?? 1
                TokenView(count: count, slug: slug, tokenFamilies: tokenFamilies)
            }
        }
    }
}
// MARK: -
struct ChoicesView: View, Sendable {
    let stack: CallStack
    let choiceTriple: [ChoiceTriple]
    let showHeader: Bool
    let automaticIndex: Int?
    @Binding var selectedChoice: Int?

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
                        Color.primary.opacity(INVISIBLE)        // Color.clear doesn't accept taps!
                            .contentShape(.rect)
                            .onTapGesture {
                                if isPaymentPossible {
                                    selectedChoice = index
                                }
                            }
                    }
                    if index == selectedChoice {
                        amountV.listRowBackground (
                            SelectedBackground(useColor: isPaymentPossible)
//                          .padding(.top, n == 1 ? 0 : -15)
//                          .padding(.bottom, n == 10 ? 0 : -15)
                        )
                    } else {
                        amountV
                    }
                } header: {
                    if showHeader {
                        if let description = contractChoice.locDescription {
                            Text(description)
                }   }   }
            }
        }
    }
}
