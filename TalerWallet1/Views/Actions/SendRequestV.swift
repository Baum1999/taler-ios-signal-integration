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
    let sendDisabled: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false

    func selectAndUpdate(_ button: Int) {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: button == 1 ? .SendAction : .RequestAction,
                                      object: nil)                              // will trigger NavigationLink
    }

    var body: some View {
        let sendTitle = String(localized: "SendButton_Short", defaultValue: "Send",
                                 comment: "Abbreviation of button `Send (currency)´")
        let requTitle = String(localized: "RequestButton_Short", defaultValue: "Request",
                                 comment: "Abbreviation of button `Request (currency)´")
        TwoRowButtons(stack: stack.push(),
                  sendTitle: sendTitle,
                   sendType: .peerPushDebit,
                   sendA11y: sendTitle,//1.tabbed(oneLine: true),
                  recvTitle: requTitle,
                   recvType: .peerPullCredit,
                   recvA11y: requTitle,//1.tabbed(oneLine: true),
                  lineLimit: 5,
               sendDisabled: sendDisabled,
                 sendAction: { controller.frontendState = -1; selectAndUpdate(1)  },
                 recvAction: { controller.frontendState = 1; selectAndUpdate(2) })
    }
}
