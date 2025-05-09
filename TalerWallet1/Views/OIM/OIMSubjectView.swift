/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// MARK: -
@available(iOS 16.4, *)
struct OIMSubjectView: View {
    let stack: CallStack
    let cash: OIMcash
    let available: Amount
    @Binding var amount: Amount
    @Binding var selectedGoal: String?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool
    let randomGoal: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var amountVal: UInt64 = 0
    @State private var sending = false              // user tapped on Send
    @State private var appeared = false
    @State private var ignoreTapped: UInt64 = 0

    func sendAction() {
        withAnimation(.basic1) {
            sending = true                              //
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            fwdButtonTapped = true          // ==> Send the money
        }
    }

    var body: some View {
//        let _ = Self._printChanges()
        let currency = cash.currency
        let noteBase = currency.noteBase
        let isSierra = noteBase == "SLE"
        let goals1 = ["shopping", "Rent", "Schooling", "Repay loan", "Medical"].shuffled()
        let goals2 = ["Phone", "Electricity", "gas pump", "Hammer", "Water"].shuffled()

        OIMnavBack(stack: stack.push(),
            currencyName: noteBase,
                 isFinal: false,
                  isGoal: false,
                isSierra: isSierra,
               isSending: sending,
                  amount: $amount,
                  action: sendAction
        ) {
            VStack {
                OIMtitleView(cash: cash, amount: available, isSending: true, secondAmount: amount)
                Spacer()
                HStack {
                    let goals = randomGoal ? goals1 : goals2
                    ForEach(goals, id: \.self) { goal in
                        if let selectedGoal {
                            if goal == selectedGoal {
                                Image(goal)
                                    .resizable()
                                    .background(Color.white)
                                    .scaledToFit()
//                                    .id(goal)
                                    .matchedGeometryEffect(id: goal, in: wrapper.namespace)
                                    .onTapGesture {
                                        withAnimation(.basic1) {
                                            self.selectedGoal = nil
                                        }
                                    }
                            }
                        } else {
                            Image(goal)
                                .resizable()
                                .background(Color.white)
                                .scaledToFit()
//                                .id(goal)
                                .matchedGeometryEffect(id: goal, in: wrapper.namespace)
                                .onTapGesture {
                                    withAnimation(.basic1) {
                                        selectedGoal = goal
                                    }
                                }
                        }
                    }
                }
                .opacity(appeared ? 1.0 : 0.01)
                .scaleEffect(appeared ? 1.0 : 0.3)

                Spacer()
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                        tappedVal: $ignoreTapped,
                          canEdit: false)
                .scaleEffect(selectedGoal == nil ? 0.6 : 1.0)
            }
//              .border(.red)
        }.task {
            amountVal = amount.centValue
            withAnimation(.basic1) {
                appeared = true
            }
        }
    }
}
