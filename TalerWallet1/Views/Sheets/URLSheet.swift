/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
    let selectedBalance: Balance?
    @Binding var urlToOpen: URL?
    let sheetURL: URL?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @AppStorage("oimEuro") var oimEuro: Bool = false

    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var summary = EMPTYSTRING
    @State private var urlCommand: UrlCommand?
    @State private var passedURL: URL?
    @State private var showAlert: Bool = false

    init(_ stack: CallStack, selectedBalance: Balance? = nil,
                                   urlToOpen: Binding<URL?>? = nil,
                                    sheetURL: URL? = nil) {
        self.stack = stack
        self.selectedBalance = selectedBalance
        self._urlToOpen = urlToOpen ?? Binding.constant(nil)
        self.sheetURL = sheetURL
    }

//  don't need  @MainActor  here
    private func passUrlOnce() {
        if urlToOpen != nil {
            passedURL = urlToOpen
            symLog.log("❗️ passed urlToOpen:  \(String(describing: urlToOpen?.absoluteString))")
            urlCommand = controller.urlCommand(urlToOpen!, stack: stack.push())
            urlToOpen = nil     // make sure we don't get this a second time
        } else if let sheetURL {
            passedURL = sheetURL
            urlCommand = controller.urlCommand(sheetURL, stack: stack.push())
        }
    }

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showAlert = false
            if let lastError = controller.lastProgressError {
                controller.lastProgressError = nil
                // TODO: cancel wallet-core operation
            }
        }
    }

    private var retryButton: some View {
        Button("Retry now") {
            showAlert = false
            // TODO: retry wallet-core operation
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(urlToOpen?.absoluteString)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        VStack {
            if controller.networkUnavailable {
                ErrorBanner(.networkUnavailable)        // red bar on top
            } else if controller.slowConnection {
                ErrorBanner(.warning5sec) // yellow bar on top
            }
            if let urlCommand, let passedURL {
                switch urlCommand {
                    case .addExchange:      // TODO: just check the ToS
                        ExchangeListView(stack: stack.push(), url: $passedURL)
                    case .withdraw:
                        WithdrawURIView(stack: stack.push(), url: passedURL)
                    case .withdrawExchange:
                        WithdrawExchangeV(stack: stack.push(),
                                selectedBalance: selectedBalance,
                                            url: passedURL)
                    case .pay:
                        PaymentView(stack: stack.push(), url: passedURL,
                                 template: false, amountToTransfer: $amountToTransfer,     summary: $summary,
                         amountIsEditable: false, summaryIsEditable: false)
                    case .payPull:
                        P2pPayURIView(stack: stack.push(), url: passedURL)
                    case .payPush:
                        P2pReceiveURIView(stack: stack.push(), url: passedURL, oimEuro:     oimEuro)
                    case .payTemplate:
                        PayTemplateV(stack: stack.push(), url: passedURL)
                    case .refund:
                        RefundURIView(stack: stack.push(), url: passedURL)
#if GNU_TALER || TALER_NIGHTLY
                    case .devExperiment:
                        DevExperimentView(stack: stack.push(), url: passedURL)
#endif
                    default:        // TODO: Error view
                        let unknown = String(localized: "Unknown command: \(passedURL.absoluteString)")
                        VStack {
                            let _ = symLog.log("Unknown command❗️ \(passedURL.absoluteString)")
                            Text(controller.messageForSheet ?? unknown)
                                .talerFont(.title)
                        }
                        .navigationTitle(unknown)
                }
            } else {
                let message = String(localized: "Scanning...", comment: "loading")
                LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                    .task(id: urlToOpen) {
                        passUrlOnce()
                    }
            }
        }
        .alert("Couldn't establish a connection", isPresented: $showAlert,
            actions: {
                if let lastPhase = controller.lastProgressPhase {
                    if lastPhase.phase == .retryable {
                        retryButton
                    }
                }
                dismissAlertButton
            },  message: {
                let lastError = controller.lastProgressError
                let fallback = String(localized: "It seems that there is a problem with the network.")
                Text(lastError?.error.hint ?? fallback)
                if let lastPhase = controller.lastProgressPhase {
                    if lastPhase.phase == .retryable {
                        if let lastError, let delay = lastError.nextRetryDelay {
                            TimeView("Next retry in:", seconds: Int(delay.toSeconds()))
                                .padding(.vertical)
                        }
                    }
                }
            }
        )
        .onChange(of: controller.stalledConnection) { isStalled in
            if isStalled {
                showAlert = true
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
