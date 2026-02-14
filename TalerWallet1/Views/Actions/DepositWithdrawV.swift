/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

///   [􁾩Deposit] [􁾭 Withdraw]
struct DepositWithdrawV: View {
    let stack: CallStack
    let sendDisabled: Bool   // can't send/deposit if wallet has no coins at all
    let recvDisabled: Bool   // can't receive/withdraw if wallet has no payments services

    var body: some View {
        let depositTitle = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                    comment: "Abbreviation of button `Deposit (currency)´")
        let withdrawTitle = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                     comment: "Abbreviation of button `Withdraw (currency)´")
        TwoRowButtons(stack: stack.push(),
                  sendTitle: depositTitle,
                   sendType: .deposit,
                   sendA11y: depositTitle,
                  recvTitle: withdrawTitle,
                   recvType: .withdrawal,
                   recvA11y: withdrawTitle,
               sendDisabled: sendDisabled,
                 sendAction: .DepositAction,
               recvDisabled: recvDisabled,
                 recvAction: .WithdrawAction)
    }
}
