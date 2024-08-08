/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct TypeButton: View {
    let title: String
    let a11y: String
    let lineLimit: Int
    var type: TransactionType
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        let hLayout = HStack {
            ButtonIconBadge(type: type, foreColor: .accentColor, done: false)
            Spacer()
            Text(title)
            Spacer()
        }

        let vLayout = VStack {
            let fragments = title.components(separatedBy: "\n")
            if fragments.count > 1 {
                Text(fragments[0])
                HStack {
                    ButtonIconBadge(type: type, foreColor: .accentColor, done: false)
                    Spacer()
                    Text(fragments[1])
                    Spacer()
                }
                if fragments.count > 2 {
                    Text(fragments[2])
                }
            } else {
                hLayout
            }
        }

        Button(action: action) {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    hLayout
                    vLayout
                }
            } else { vLayout } // view for iOS 15
        }
        .accessibilityLabel(Text(a11y))
        .lineLimit(lineLimit)
        .disabled(disabled)
        .buttonStyle(TalerButtonStyle(type: .bordered,
                                    dimmed: false,
                                  disabled: disabled,
                                   aligned: .center))
    }
}


struct TwoRowButtons: View {
    let stack: CallStack
    let sendTitle: String
    var sendType: TransactionType
    let sendA11y: String
    let recvTitle: String
    var recvType: TransactionType
    let recvA11y: String
    let fitsSideBySide: Bool            // whether both buttons fit in one line
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
            TypeButton(title: sendButtonTitle,
                        a11y: sendA11y,
                   lineLimit: lineLimit,
                        type: sendType,
                    disabled: sendDisabled,
                      action: sendAction)
            let recvButtonTitle = recvTitle.tabbed(oneLine: !fitsSideBySide)
            TypeButton(title: recvButtonTitle,
                        a11y: recvA11y,
                   lineLimit: lineLimit,
                        type: recvType,
                    disabled: false,
                      action: recvAction)
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
