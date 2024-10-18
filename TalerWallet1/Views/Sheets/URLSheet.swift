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
    var urlToOpen: URL

    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @EnvironmentObject private var controller: Controller
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var summary = EMPTYSTRING
    @State private var urlCommand: UrlCommand = .unknown

    let navTitle = String(localized: "Checking Link")

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            switch urlCommand {
                case .termsExchange,      // TODO: just check the ToS
                     .withdraw:
                    WithdrawURIView(stack: stack.push(), url: urlToOpen)
                case .withdrawExchange:
                    WithdrawExchangeV(stack: stack.push(),
                            selectedBalance: $selectedBalance,
                                        url: urlToOpen)
                case .pay:
                    PaymentView(stack: stack.push(), url: urlToOpen,
                             template: false, amountToTransfer: $amountToTransfer, summary: $summary,
                     amountIsEditable: false, summaryIsEditable: false)
                case .payPull:
                    P2pPayURIView(stack: stack.push(), url: urlToOpen)
                case .payPush:
                    P2pReceiveURIView(stack: stack.push(), url: urlToOpen)
                case .payTemplate:
                    PayTemplateV(stack: stack.push(), url: urlToOpen)
                case .refund:
                    RefundURIView(stack: stack.push(), url: urlToOpen)
                default:        // Error view
                    VStack {
                        Text("unknown command")
                            .talerFont(.title)
                        Text(controller.messageForSheet ?? urlToOpen.absoluteString)
                    }
                    .navigationTitle(navTitle)
            }
        }
        .task {
            let command = controller.openURL(urlToOpen, stack: stack.push())
            urlCommand = command
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
