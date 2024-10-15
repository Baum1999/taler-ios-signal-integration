/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct DepositWithdrawV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let sendDisabled: Bool          // can't send/deposit if wallet has no coins

    @MainActor
    func dismissAndPost(_ name: NSNotification.Name) {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: name, object: nil)              // will trigger NavigationLink
    }

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
                 sendAction: { dismissAndPost(.DepositAction) },
                 recvAction: { dismissAndPost(.WithdrawAction) })
    }
}
