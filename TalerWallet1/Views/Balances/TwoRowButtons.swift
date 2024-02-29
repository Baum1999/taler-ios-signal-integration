/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct TwoRowButtons: View {
    let stack: CallStack
    let sendTitle: String
    let recvTitle: String
    let fitsSideBySide: Bool
    let lineLimit: Int
    let sendDisabled: Bool
    let sendAction: () -> Void
    let recvAction: () -> Void

//    @Environment(\.sizeCategory) var sizeCategory
    func makeCopy(fitsSideBySide: Bool) -> TwoRowButtons {
        TwoRowButtons(stack: stack.push(),
                  sendTitle: sendTitle,
                  recvTitle: recvTitle,
             fitsSideBySide: fitsSideBySide,
                  lineLimit: lineLimit,
               sendDisabled: sendDisabled,
                 sendAction: sendAction,
                 recvAction: recvAction)
    }

    var body: some View {
        Group {
            let sendButtonTitle = sendTitle.tabbed(oneLine: !fitsSideBySide)
            let sendVoiceOverTitle = sendTitle.tabbed(oneLine: true)
            Button(sendButtonTitle, action: sendAction)
                .accessibilityLabel(Text(sendVoiceOverTitle))
                .lineLimit(lineLimit)
                .disabled(sendDisabled)
                .buttonStyle(TalerButtonStyle(type: .bordered,
                                            dimmed: false,
                                          disabled: sendDisabled,
                                           aligned: .center))
            let recvButtonTitle = recvTitle.tabbed(oneLine: !fitsSideBySide)
            let recvVoiceOverTitle = recvTitle.tabbed(oneLine: true)
            Button(recvButtonTitle, action: recvAction)
                .accessibilityLabel(Text(recvVoiceOverTitle))
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
                      recvTitle: "Request " + LONGCURRENCY,
                 fitsSideBySide: false,
                      lineLimit: 2, sendDisabled: true,
                     sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
            TwoRowButtons(stack: CallStack("Preview"),
                      sendTitle: "Send " + DEMOCURRENCY,
                      recvTitle: "Request " + DEMOCURRENCY,
                 fitsSideBySide: true,
                      lineLimit: 2, sendDisabled: true,
                     sendAction: {}, recvAction: {})
                .listRowSeparator(.hidden)
        }
    }
}
#endif
