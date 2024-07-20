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
    let navTitle = String(localized: "Checking Link")
    var urlToOpen: URL

    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @EnvironmentObject private var controller: Controller
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var summary = EMPTYSTRING
    @State private var showAlert: Bool = false
    @State private var urlCommand: UrlCommand = .unknown

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let warning = String(localized: "It seems you wanted to request money - but this transaction will let you pay...")

        Group {
            switch urlCommand {
                case .withdraw:
                    WithdrawURIView(stack: stack.push(), url: urlToOpen)
                case .withdrawExchange:
                    WithdrawExchangeV(stack: stack.push(), url: urlToOpen)
                case .termsExchange:
                    WithdrawExchangeV(stack: stack.push(), url: urlToOpen)      // TODO: just check the ToS
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
            let incomingExpected = controller.frontendState == 1
            let command = controller.openURL(urlToOpen, stack: stack.push())
            if incomingExpected && command.isOutgoing {
                showAlert = true
            }
            urlCommand = command
        }
        .alert(warning, isPresented: $showAlert, actions: {
            Button("Cancel", role: .cancel) {
                showAlert = false
                dismissTop(stack.push())
            }
            Button("OK") {
                showAlert = false
            }
          }, message: { Text("\nWarnings can be switched off in Settings") }
        )
    }
}
// MARK: -
//struct PaySheet_Previews: PreviewProvider {
//    static var previews: some View {
            // needs BackendManager
//        URLSheet(urlToOpen: URL(string: "ftp://this.URL.is.invalid")!)
//    }
//}
