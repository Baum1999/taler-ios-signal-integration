/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct GoalsHStack: View {
    let goals: [String]
    @Binding var selectedGoal: String?

    @EnvironmentObject private var wrapper: NamespaceWrapper

    var body: some View {
        HStack {
            ForEach(goals, id: \.self) { goal in
                if let selectedGoal {
                    if goal == selectedGoal {
                        Image(goal)
                            .resizable()
                            .background(Color.white)
                            .scaledToFit()
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
                        .matchedGeometryEffect(id: goal, in: wrapper.namespace)
                        .onTapGesture {
                            withAnimation(.basic1) {
                                selectedGoal = goal
                            }
                        }
                }
            }
        }
    }
}
// MARK: -
@available(iOS 16.4, *)
struct OIMSubjectView: View {
    let stack: CallStack
    let cash: OIMcash
    let available: Amount
    @Binding var amountToTransfer: Amount
    @Binding var selectedGoal: String?
//    let decimal: Int            // 0 for ¥,HUF;   2 for $,€,£;   3 for ﷼,₯ (arabic)
    @Binding var fwdButtonTapped: Bool

    @Environment(\.dismiss) var dismiss     // pop back once
    @EnvironmentObject private var wrapper: NamespaceWrapper

    @State private var amount2: Amount? = nil
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
        let goals1 = ["blank", "Phone", "Electricity", "gas pump", "Hammer", "Water"]
        let goals2 = ["shopping", "Rent", "Schooling", "Repay loan", "Medical"].shuffled()

        let gotAction = (selectedGoal != nil) ? sendAction : nil
        OIMnavBack(stack: stack.push(),
            currencyName: noteBase,
                 isFinal: false,
                isSierra: isSierra,
               isSending: sending,
                  amount: amount2,
                  action: gotAction
        ) {
            VStack {
                OIMtitleView(cash: cash, amount: available, isSending: true, secondAmount: amountToTransfer)
                Spacer()
                GoalsHStack(goals: goals1, selectedGoal: $selectedGoal)
                    .opacity(appeared ? 1.0 : 0.01)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                GoalsHStack(goals: goals2, selectedGoal: $selectedGoal)
                    .opacity(appeared ? 1.0 : 0.01)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                Spacer()
                OIMlineView(stack: stack.push(),
                             cash: cash,
                        amountVal: $amountVal,
                        tappedVal: $ignoreTapped,
                          canEdit: false)
                    .scaleEffect(selectedGoal == nil ? 0.6 : 1.0)
                    .onTapGesture {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            dismiss()
                        }
                    }
            }
//              .border(.red)
        }.task {
            amount2 = amountToTransfer
            amountVal = amountToTransfer.centValue
            withAnimation(.basic1) {
                appeared = true
            }
        }
    }
}
