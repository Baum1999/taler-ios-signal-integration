/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct TwoRowButtons: View {
    let stack: CallStack
    let sendTitle: String
    var sendType: TransactionType
    let sendA11y: String
    let recvTitle: String
    var recvType: TransactionType
    let recvA11y: String
    let fitsSideBySide: Bool
    let lineLimit: Int
    let sendDisabled: Bool
    let sendAction: () -> Void
    let recvAction: () -> Void

//    @Environment(\.sizeCategory) var sizeCategory
    func makeCopy(fitsSideBySide: Bool) -> TwoRowButtons {
        TwoRowButtons(stack: stack.push(),
                  sendTitle: sendTitle,
                   sendType: sendType,
                   sendA11y: sendA11y,
                  recvTitle: recvTitle,
                   recvType: recvType,
                   recvA11y: recvA11y,
             fitsSideBySide: fitsSideBySide,
                  lineLimit: lineLimit,
               sendDisabled: sendDisabled,
                 sendAction: sendAction,
                 recvAction: recvAction)
    }

    var body: some View {
        Group {
            let sendButtonTitle = sendTitle.tabbed(oneLine: !fitsSideBySide)
            Button(action: sendAction) {
                HStack {
                    ButtonIconBadge(type: sendType, foreColor: .accentColor, done: false)
                    Spacer()
                    Text(sendButtonTitle)
                    Spacer()
                }
            }
                .accessibilityLabel(Text(sendA11y))
                .lineLimit(lineLimit)
                .disabled(sendDisabled)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                          disabled: sendDisabled,
                                           aligned: .center))
            let recvButtonTitle = recvTitle.tabbed(oneLine: !fitsSideBySide)
            Button(action: recvAction) {
                HStack {
                    ButtonIconBadge(type: recvType, foreColor: .accentColor, done: false)
                    Spacer()
                    Text(recvButtonTitle)
                    Spacer()
                }
            }
                .accessibilityLabel(Text(recvA11y))
                .lineLimit(lineLimit)
                .disabled(false)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                           aligned: .center))
        }
    }
}
// MARK: -
#if  DEBUG
struct TwoRowButtons_Previews: PreviewProvider {
    static var previews: some View {
        List {
            TwoRowButtons(stack: CallStack("Preview"),
                      sendTitle: "Send " + TESTCURRENCY,
                       sendType: .peerPushDebit,
                       sendA11y: "Send " + TESTCURRENCY,
                      recvTitle: "Request " + LONGCURRENCY,
                       recvType: .peerPullCredit,
                       recvA11y: "Request " + LONGCURRENCY,
                 fitsSideBySide: false,
                      lineLimit: 2, sendDisabled: true,
                     sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
            TwoRowButtons(stack: CallStack("Preview"),
                      sendTitle: "Send " + DEMOCURRENCY,
                       sendType: .peerPushDebit,
                       sendA11y: "Send " + DEMOCURRENCY,
                      recvTitle: "Request " + DEMOCURRENCY,
                       recvType: .peerPullCredit,
                       recvA11y: "Request " + DEMOCURRENCY,
                 fitsSideBySide: true,
                      lineLimit: 2, sendDisabled: true,
                     sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
        }
    }
}
#endif
