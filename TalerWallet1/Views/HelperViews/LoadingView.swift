/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct LoadingView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scopeInfo: ScopeInfo?
    let message: String?

//    let backButtonHidden: Bool
    let navTitle = String(localized: "Loading…")

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var rotationEnabled = true
    @State private var showAlert: Bool = false
    @State private var disabled: Bool = false
    @State private var isFinished: Bool? = false

    private var dismissButton: some View {
        Button("Cancel", role: .cancel) {
            showAlert = false
            if let token = controller.progressToken {
                controller.progressToken = nil
                if let operation = controller.progressOperation {
                    controller.progressOperation = nil
//                  model.setError(nil)
                    Task {
                        try await model.cancelProgressToken(operation, token: token)
                        if !developerMode {
                            model.setError(nil)
                        }
                    }
                }
                if !developerMode {
                    dismissTop(stack.push())
                }
            } else {
                dismissTop(stack.push())
            }
        }
            .buttonStyle(TalerButtonStyle(type: .bordered, disabled: false))
            .padding(.horizontal)
    }

    @ViewBuilder
    func retryButton(disabled: Bool) -> some View {
        Button("Retry now") {
            withAnimation {
                showAlert = false
            }
            if let lastError = controller.lastProgressError {
                controller.lastProgressError = nil
                Task {
                    try await model.retryProgressTokenNow(lastError.operation,
                                                   token: lastError.progressToken)
            }   }
        }
            .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
            .padding(.horizontal)
    }

    var body: some View {
        let view = VStack(alignment: .center) {
            if showAlert {
                let lastError = controller.lastProgressError
                let fallback = String(localized: "It seems that there is a problem with the network.")
                Text("Couldn't establish a connection")
                    .talerFont(.title2)
                    .padding(.vertical)
                Text(lastError?.error.hint ?? fallback)
                    .talerFont(.body)
                Spacer()
                if let lastPhase = controller.lastProgressPhase {
                    if lastPhase.phase == .stalled {
                        if let lastError, let delay = lastError.nextRetryDelay {
                            if isFinished == false {
                                TimeView("Next retry in:", seconds: Int(delay.toSeconds()), isFinished: $isFinished)
                                    .talerFont(.title3)
                                    .padding(.vertical)
                            } else if isFinished == true {
                                Text("Retrying…")
                                    .talerFont(.title3)
                            } else {
                                Text("Waiting for response…")
                                    .talerFont(.title3)
                            }
                        }
//                        Spacer()
                        retryButton(disabled: isFinished ?? false)
                    }
                }
            } else {
                Spacer()
                RotatingTaler(size: 100,
                          progress: true,                 // VoiceOver "In progress"
                              once: false,
                   rotationEnabled: $rotationEnabled)
                    .onTapGesture(count: 1) {
                        rotationEnabled.toggle()
                    }
                Spacer()
                if let scopeInfo {
                    if let urlStr = scopeInfo.url {
                        Text(urlStr.trimURL)
                            .talerFont(.title2)
                    } else {
                        Text(scopeInfo.currency)
                            .talerFont(.title2)
                    }
                    Spacer()
                }
                Text(message ?? EMPTYSTRING)
                    .talerFont(.title2)
                Spacer()
            }
            dismissButton
        }
        .frame(maxWidth: .infinity)
        .talerFont(.title)
        .navigationTitle(navTitle)
        .background(FullBackground())
        .onChange(of: controller.stalledConnection) { isStalled in
            showAlert = isStalled
        }
        .onChange(of: controller.errorConnection) { isError in
            if isError {
//                print("❗️❗️❗️ error arrived, idle waiting starts")
                isFinished = false
                controller.errorConnection = false
            }
        }

        if #available(iOS 17.0, *) {
            view.toolbarTitleDisplayMode(.inlineLarge)
        } else {
            view
        }
    }
}
// MARK: -
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoadingView(stack: CallStack("Loading"), scopeInfo: nil, message: "test message")  // , backButtonHidden: true)
                .navigationBarTitleDisplayMode(.automatic)
        }.navigationViewStyle(.stack)
    }
}
