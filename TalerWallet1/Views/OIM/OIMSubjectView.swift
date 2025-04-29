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

    @State private var amountVal: UInt64 = 0
    @State private var sending = false              // user tapped on Send
    @State private var smallAmount = false
    @State private var tappedVal: UInt64 = 0
    @State private var selectedGoals: [String] = []
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
            ZStack(alignment: .top) {
                VStack {
                    Spacer()
                    OIMlineView(stack: stack.push(),
                                 cash: cash,
                            amountVal: $amountVal,
                            tappedVal: $tappedVal,          // <- user tapped a val in the scroller
                              canEdit: false)
                    .scaleEffect(0.6)
                }
                VStack {
                    Spacer()
                    HStack {
                        ForEach(goals, id: \.self) { goal in
                            let isSelected = selectedGoals.contains(goal)
                            Image(goal)
                                .resizable()
                                .scaledToFit()
                                .border(isSelected ? WalletColors().talerColor : Color.clear)
                                .onTapGesture {
                                    if isSelected {
                                        selectedGoals.removeAll(where: { $0 == goal } )
                                    } else {
                                        selectedGoals.append(goal)
                                    }
                                }
                        }
                    }
                    Spacer()
                }
//              .border(.red)
            }
        }.task {
            amountVal = amount.centValue
            withAnimation(.basic1) {
                smallAmount = true
            }
        }
    }
}
