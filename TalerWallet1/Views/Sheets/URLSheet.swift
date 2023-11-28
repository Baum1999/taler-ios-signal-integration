/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct URLSheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Checking Link")
    var urlToOpen: URL

    @EnvironmentObject private var controller: Controller

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let urlCommand = controller.openURL(urlToOpen, stack: stack.push())

        Group {
            switch urlCommand {
                case .withdraw:
                    WithdrawURIView(stack: stack.push(), url: urlToOpen)
                case .pay:
                    PaymentView(stack: stack.push(), url: urlToOpen)
                case .payPull:
                    P2pPayURIView(stack: stack.push(), url: urlToOpen)
                case .payPush:
                    P2pReceiveURIView(stack: stack.push(), url: urlToOpen)
                case .payTemplate:
                    PayTemplateView(stack: stack.push(), url: urlToOpen)
                case .refund:
                    RefundURIView(stack: stack.push(), url: urlToOpen)
//                case .reward:
//                    RewardURIView(url: urlToOpen)
                default:        // Error view
                    VStack {
                        Text("unknown command")
                            .accessibilityFont(.title)
                        Text(controller.messageForSheet ?? urlToOpen.absoluteString)
                    }
                    .navigationTitle(navTitle)
            }
        }
    }
}
// MARK: -
//struct PaySheet_Previews: PreviewProvider {
//    static var previews: some View {
            // needs BackendManager
//        URLSheet(urlToOpen: URL(string: "ftp://this.URL.is.invalid")!)
//    }
//}
