/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

let LINELIMIT = 5

struct TypeButton: View {
    let stack: CallStack
    let title: String
    let a11y: String
    var type: TransactionType
    let disabled: Bool
    let action: NSNotification.Name

    @AppStorage("minimalistic") var minimalistic: Bool = false

    @MainActor
    func dismissAndPost() {
        dismissTop(stack.push())
        NotificationCenter.default.post(name: action, object: nil)                // will trigger NavigationLink
    }

    var body: some View {
#if DEBUG
        let debug = 1==0
        let red = debug ? Color.red : Color.clear
        let green = debug ? Color.green : Color.clear
        let blue = debug ? Color.blue : Color.clear
        let orange = debug ? Color.orange : Color.clear
#endif
        let badge = ButtonIconBadge(type: type, foreColor: .accentColor, done: false)
        let hLayout = HStack {
            badge
            Spacer()
            Text(title)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
        }
#if DEBUG
            .border(red)
#endif

        let vLayout = VStack {
            let fragments = title.components(separatedBy: "\n")
            if fragments.count > 1 {
                Text(fragments[0])
                HStack {
                    badge
                    Spacer()
                    Text(fragments[1])
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                }
#if DEBUG
                .border(orange)
#endif
                if fragments.count > 2 {
                    Text(fragments[2])
//                        .fixedSize(horizontal: true, vertical: false)
#if DEBUG
                        .border(green)
#endif
                }
            } else {
                hLayout
            }
        }
#if DEBUG
            .border(red)
#endif

        Button(action: dismissAndPost) {
            if minimalistic {
                badge
            } else {
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        hLayout
                        vLayout
                    }
                } else { vLayout } // view for iOS 15
            }
        }
        .accessibilityLabel(Text(a11y))
        .lineLimit(LINELIMIT)
        .disabled(disabled)
        .buttonStyle(TalerButtonStyle(type: .bordered,
                                    dimmed: false,
                                  disabled: disabled,
                                   aligned: .center))
    }
}
// MARK: -
struct TwoRowButtons: View {
    let stack: CallStack
    let sendTitle: String
    var sendType: TransactionType
    let sendA11y: String
    let recvTitle: String
    var recvType: TransactionType
    let recvA11y: String
    let sendDisabled: Bool   // can't send/deposit if wallet has no coins at all
    let sendAction: NSNotification.Name
    let recvDisabled: Bool   // can't receive/withdraw if wallet has no payments services
    let recvAction: NSNotification.Name

    func sendButton(_ title: String) -> TypeButton {
        TypeButton(stack: stack.push(),
                   title: title,
                    a11y: sendA11y,
                    type: sendType,
                disabled: sendDisabled,
                  action: sendAction)
    }

    func recvButton(_ title: String) -> TypeButton {
        TypeButton(stack: stack.push(),
                   title: title,
                    a11y: recvA11y,
                    type: recvType,
                disabled: recvDisabled,
                  action: recvAction)
    }

    var body: some View {
        let hLayout = HStack(spacing: HSPACING) {
            // side by side, text in 1+ lines (\t -> \n)
            sendButton(sendTitle.tabbed(oneLine: false))
            recvButton(recvTitle.tabbed(oneLine: false))
        }
        let vLayout = VStack {
            // one below the other, text in one line (\t -> " ")
            sendButton(sendTitle.tabbed(oneLine: true))
            recvButton(recvTitle.tabbed(oneLine: true))
        }

        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                hLayout
//                    .border(.green)
                vLayout
//                    .border(.red)
            }
        } else { vLayout } // iOS 15 has no ViewThatFits
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
                   sendDisabled: true,
                     sendAction: .SendAction,
                   recvDisabled: false,
                     recvAction: .RequestAction)
                .listRowSeparator(.hidden)
            TwoRowButtons(stack: CallStack("Preview"),
                      sendTitle: "Send " + DEMOCURRENCY,
                       sendType: .peerPushDebit,
                       sendA11y: "Send " + DEMOCURRENCY,
                      recvTitle: "Request " + DEMOCURRENCY,
                       recvType: .peerPullCredit,
                       recvA11y: "Request " + DEMOCURRENCY,
                   sendDisabled: true,
                     sendAction: .SendAction,
                   recvDisabled: false,
                     recvAction: .RequestAction)
                .listRowSeparator(.hidden)
        }
    }
}
#endif
