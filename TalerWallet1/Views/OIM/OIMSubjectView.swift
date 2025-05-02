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
    @Binding var amount: Amount
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool

    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var amountVal: UInt64 = 0
    @State private var sending = false              // user tapped on Send
    @State private var appearing = false
    @State private var ignoreTapped: UInt64 = 0
    @State private var selectedGoal: String?
    let goals = ["Buy goods in shop", "Rent", "Schooling", "Repay loan", "Medical or health issue"]

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

        OIMnavBack(stack: stack.push(),
            currencyName: noteBase,
                 isFinal: true,
                  isGoal: false,
                isSierra: isSierra,
               isSending: sending,
                  amount: $amount,
                  action: sendAction
        ) {
            VStack {
                OIMtitleView(cash: cash, amount: amount, isSending: true, secondAmount: amount)
                Spacer()
                HStack {
                    ForEach(goals, id: \.self) { goal in
                        if let selectedGoal {
                            if goal == selectedGoal {
                                Image(goal)
                                    .resizable()
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
                .opacity(appearing ? 1.0 : 0.01)
                .scaleEffect(appearing ? 1.0 : 0.3)

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
                appearing = true
            }
        }
    }
}
