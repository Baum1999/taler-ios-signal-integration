/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

typealias ChoiceTriple = (ChoiceSelectionDetail, ContractChoice, Int)

struct ChoicesView: View, Sendable {
    let stack: CallStack
    let choiceTriple: [ChoiceTriple]
    @Binding var selectedChoice: Int

    @ViewBuilder
    func selectedBackground(_ useColor: Bool) -> some View {
        let is26: Bool = if #available(iOS 26.0, *) { true } else { false }
        let color: Color = useColor ? WalletColors().talerColor
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

    var body: some View {
        ForEach(choiceTriple, id: \.1) { choice in
            let selectionDetail: ChoiceSelectionDetail = choice.0
            let contractChoice: ContractChoice = choice.1
            let index: Int = choice.2
            let isPaymentPossible = selectionDetail.status == .paymentPossible
            if let description = contractChoice.description {
                Section(header: Text(description)) {
                    let amountV = HStack {
                        Spacer()
                        AmountV(stack: stack.push(),
                                scope: nil,
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
                }
            }
        }
    }
}
