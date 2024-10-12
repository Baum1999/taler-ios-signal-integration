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
    let sendDisabled: Bool

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    func selectAndUpdate(_ button: Int) {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: button == 3 ? .DepositAction : .WithdrawAction,
                                      object: nil)                              // will trigger NavigationLink
    }

    var body: some View {
        let depositTitle = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                    comment: "Abbreviation of button `Deposit (currency)´")
        let withdrawTitle = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                     comment: "Abbreviation of button `Withdraw (currency)´")
        TwoRowButtons(stack: stack.push(),
                  sendTitle: depositTitle,
                   sendType: .deposit,
                   sendA11y: depositTitle,//1.tabbed(oneLine: true),
                  recvTitle: withdrawTitle,
                   recvType: .withdrawal,
                   recvA11y: withdrawTitle,//1.tabbed(oneLine: true),
                  lineLimit: 5,
               sendDisabled: sendDisabled,
                 sendAction: { selectAndUpdate(3) },
                 recvAction: { selectAndUpdate(4) })
    }
}
