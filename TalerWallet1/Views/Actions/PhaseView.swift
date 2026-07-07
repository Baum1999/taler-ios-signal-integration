/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct PhaseView: View {
    let stack: CallStack
    let date: Date
//    let phase: Int
    let sendDisabled: Bool   // can't send/deposit if wallet has no coins at all
    let recvDisabled: Bool   // can't receive/withdraw if wallet has no payments services
    let depoDisabled: Bool
    let wthdDisabled: Bool

#if TALER_NIGHTLY
    @State private var phaseCounter = -5
#else
    @State private var phaseCounter = -300
#endif

    func phase(_ first: Bool) -> Int {
        if phaseCounter >= 0 {
            let myPhase = phaseCounter % 32
            if first {
                return myPhase > 15 ? 0 : myPhase
            }
            return myPhase < 17 ? 0 : myPhase - 16
        }
        return 0
    }

    var body: some View {
        let sendTitle = String(localized: "SendButton_Short", defaultValue: "Send",
                               comment: "Abbreviation of button `Send (currency)´")
        let requTitle = String(localized: "RequestButton_Short", defaultValue: "Request",
                               comment: "Abbreviation of button `Request (currency)´")

        ///   [􁉇 Send   ] [􁉅 Request]
        TwoRowButtons(stack: stack.push(),
                      phase: phase(true),
                  sendTitle: sendTitle,
                   sendType: .peerPushDebit,
                   sendA11y: sendTitle,
                  recvTitle: requTitle,
                   recvType: .peerPullCredit,
                   recvA11y: requTitle,
               sendDisabled: sendDisabled,
                 sendAction: .SendAction,
               recvDisabled: recvDisabled,
                 recvAction: .RequestAction)
        .accessibility(sortPriority: 1)     // read this after maps
        .onChange(of: date) { _ in
            phaseCounter += 1
        }

        let depositTitle = String(localized: "DepositButton_Short", defaultValue: "Deposit",
                                    comment: "Abbreviation of button `Deposit (currency)´")
        let withdrawTitle = String(localized: "WithdrawButton_Short", defaultValue: "Withdraw",
                                     comment: "Abbreviation of button `Withdraw (currency)´")
        ///   [􁾩Deposit] [􁾭 Withdraw]
        TwoRowButtons(stack: stack.push(),
                      phase: phase(false),
                  sendTitle: depositTitle,
                   sendType: .deposit,
                   sendA11y: depositTitle,
                  recvTitle: withdrawTitle,
                   recvType: .withdrawal,
                   recvA11y: withdrawTitle,
               sendDisabled: depoDisabled,
                 sendAction: .DepositAction,
               recvDisabled: wthdDisabled,
                 recvAction: .WithdrawAction)
        .accessibility(sortPriority: 0)     // read this last
    }
}
