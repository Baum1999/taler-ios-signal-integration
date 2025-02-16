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

struct URLSheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
    @Binding var urlToOpen: URL?

    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @EnvironmentObject private var controller: Controller
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var summary = EMPTYSTRING
    @State private var urlCommand: UrlCommand?
    @State private var passedURL: URL?

    private func passUrlOnce() {
        if urlToOpen != nil {
            passedURL = urlToOpen
            urlCommand = controller.openURL(urlToOpen!, stack: stack.push())
            urlToOpen = nil
            symLog.log("❗️ erase urlToOpen:  \(urlToOpen?.absoluteString)")
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let urlCommand, let passedURL {
            switch urlCommand {
                case .termsExchange,      // TODO: just check the ToS
                     .withdraw:
                    WithdrawURIView(stack: stack.push(), url: passedURL)
                case .withdrawExchange:
                    WithdrawExchangeV(stack: stack.push(),
                            selectedBalance: $selectedBalance,
                                        url: passedURL)
                case .pay:
                    PaymentView(stack: stack.push(), url: passedURL,
                             template: false, amountToTransfer: $amountToTransfer, summary: $summary,
                     amountIsEditable: false, summaryIsEditable: false)
                case .payPull:
                    P2pPayURIView(stack: stack.push(), url: passedURL)
                case .payPush:
                    P2pReceiveURIView(stack: stack.push(), url: passedURL)
                case .payTemplate:
                    PayTemplateV(stack: stack.push(), url: passedURL)
                case .refund:
                    RefundURIView(stack: stack.push(), url: passedURL)
                default:        // TODO: Error view
                    VStack {
                        let _ = symLog.log("Unknown command❗️ \(passedURL.absoluteString)")
                        Text(controller.messageForSheet ?? passedURL.absoluteString)
                    }
                    .navigationTitle("Unknown command")
            }
        } else {
            let message = String(localized: "Scanning...", comment: "loading")
            LoadingView(scopeInfo: nil, message: message)
                .task(id: urlToOpen) {
                    passUrlOnce()
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
