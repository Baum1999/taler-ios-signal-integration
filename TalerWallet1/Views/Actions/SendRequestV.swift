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

struct SendRequestV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let sendDisabled: Bool          // can't send/deposit if wallet has no coins

    @MainActor
    func dismissAndPost(_ name: NSNotification.Name) {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: name, object: nil)              // will trigger NavigationLink
    }

    var body: some View {
        let sendTitle = String(localized: "SendButton_Short", defaultValue: "Send",
                                 comment: "Abbreviation of button `Send (currency)´")
        let requTitle = String(localized: "RequestButton_Short", defaultValue: "Request",
                                 comment: "Abbreviation of button `Request (currency)´")
        TwoRowButtons(stack: stack.push(),
                  sendTitle: sendTitle,
                   sendType: .peerPushDebit,
                   sendA11y: sendTitle,
                  recvTitle: requTitle,
                   recvType: .peerPullCredit,
                   recvA11y: requTitle,
               sendDisabled: sendDisabled,
                 sendAction: { dismissAndPost(.SendAction) },
                 recvAction: { dismissAndPost(.RequestAction) })
    }
}
