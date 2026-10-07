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
    let choiceTriples: [ChoiceTriple]
    let tokenFamilies: [String: ContractTokenFamily]?   // token_family_slug: String
    let showHeader: Bool
    let automaticIndex: Int?
    @Binding var selectedChoice: Int?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Section {
            ForEach(choiceTriples, id: \.2) { triple in
                let selectionDetail: ChoiceSelectionDetail = triple.0
                let contractChoice: ContractChoice = triple.1
                let index: Int = triple.2
                let isPaymentPossible = selectionDetail.status == .paymentPossible
                let payAutomatic = automaticIndex == index
                let scopeInfo = selectionDetail.scopeInfo
                let amount = selectionDetail.amountRaw
                /// If it contains money, always show it. Disable but don’t hide it if insufficient - that serves as advertisement what you could buy if you had more money / tokens.
                /// If it only contains tokens, and insufficient, then hide it. Most probably there is a money payment option to acquire those tokens, which is advertisement enough.
                /// Tokens only, paymentPossible. If automaticIndex, then also hide it (and auto-pay it). Otherwise show it, so the user can select it.
                if (!amount.isZero || isPaymentPossible) && !payAutomatic {
                    VStack(alignment: .leading) {
                        if showHeader {     // V1
                            if let description = contractChoice.locDescription {
                                Text(description)
                                    .talerFont(.body)
                            }   }

                        HStack {
                            Spacer()
                            AmountV(stack: stack.push(),
                                    scope: scopeInfo,
                                   amount: contractChoice.amount)
                            .foregroundColor(isPaymentPossible ? .primary : .secondary)
                        }
                        if let tokenFamilies {
                            // Spend Input tokens
                            let inputs = contractChoice.inputs
                            if !inputs.isEmpty {
                                Text("Spend now:")
                                    .talerFont(.body)
                                    .padding(.bottom, -4)
                                InputTokenView(inputs: inputs, tokenFamilies: tokenFamilies)
                            }
                            // Receive output tokens
                            let outputs = contractChoice.outputs
                            if !outputs.isEmpty {
                                Text("Get with your purchase:")
                                    .talerFont(.body)
                                    .padding(.bottom, -4)
                                OutputTokenView(outputs: outputs, tokenFamilies: tokenFamilies)
                            }
                        }
                    }.overlay {
                        Color.primary.opacity(INVISIBLE)        // Color.clear doesn't accept taps!
                            .contentShape(.rect)
                            .onTapGesture {
                                if isPaymentPossible {
                                    selectedChoice = index
                                }
                            }
                    }
                    .listRowBackground(
                        SelectedBackground(useColor: index == selectedChoice ? isPaymentPossible : nil)
                    )
                }
            }.listRowSeparator(.hidden)
        } header: {
            Text("Payment Options")
                .talerFont(.title3)
                .foregroundColor(WalletColors().secondary2(colorScheme, colorSchemeContrast))
        }
    }
}
// MARK: -
struct ProductsView: View, Sendable {
    let stack: CallStack
    let scope: ScopeInfo?
    let products: [ProductSold]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        if !products.isEmpty {
            Section {
                ForEach(products, id: \.self) { product in
                    HStack {
                        VStack(alignment: .leading) {
                            if let name = product.productName {
                                Text(name)
                                    .bold()
                                    .talerFont(.body)
                            }
                            Text(product.locDescription)
                                .talerFont(.subheadline)

                            HStack {
                                if let quantity = product.unitQuantity {
                                    Text(quantity)
                                }
                                if let unit = product.unit {
                                    // TODO: MerchantUnit
                                    Text(unit)
                                }
                            }.talerFont(.subheadline)
                        }
                        Spacer()
                        if let price = product.prices?.first ?? product.price {
                            AmountV(scope, price, isNegative: nil)
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}
