/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct StalledView: View {

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var isFinished: Bool? = false

    @ViewBuilder
    func retryButton(disabled: Bool) -> some View {
        Button("Retry now") {
            if let token = controller.progressToken {
                if let operation = controller.progressOperation {
                    controller.lastProgressError = nil
                    Task {
                        try await model.retryProgressTokenNow(operation, token: token)
                    }
                }
            }
        }
        .buttonStyle(TalerButtonStyle(type: .bordered, disabled: disabled))
        .padding(.horizontal)
    }

    fileprivate func toJSON(_ lastError: RequestProgressError?) -> String? {
        if let lastError {
            do {
                let jsonData = try JSONEncoder().encode(lastError)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    return jsonString
                }
            } catch {        // JSON encoding of error failed / should never happen
                return "Couldn't encode error"
            }
        }
        return nil
    }

    var body: some View {
        Group {
            let lastError = controller.lastProgressError
            let fallback = String(localized: "It seems that there is a problem with the network.")
            Text("Couldn't establish a connection")
                .talerFont(.title2)
                .padding(.vertical)
            let hint = lastError?.error.hint
            ?? lastError?.error.errorResponse?.hint
            Text(hint ?? fallback)
                .talerFont(.body)
            if let jsonString = toJSON(lastError) {
                CopyButton(jsonString, title: "Copy Details")
                    .padding(.vertical)
            }
            if let lastPhase = controller.lastProgressPhase {
                if lastPhase.phase == .stalled {
                    if let lastError, let delay = lastError.nextRetryDelay {
                        ZStack {
                            TimeView("Next retry in:", seconds: Int(delay.toSeconds()), isFinished: $isFinished)
                                .talerFont(.title3)
                                .padding(.vertical)
                                .opacity(isFinished == false ? 1 : 0)
                            Text("Retrying…")
                                .talerFont(.title3)
                                .opacity(isFinished == true ? 1 : 0)
                            Text("Waiting for response…")
                                .talerFont(.title3)
                                .opacity(isFinished == nil ? 1 : 0)
                        }
                        retryButton(disabled: isFinished ?? false)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .onChange(of: controller.errorConnection) { isError in
            if isError {
//                print("❗️❗️❗️ error arrived, idle waiting starts")
                withAnimation {
                    isFinished = false
                }
                controller.errorConnection = false
            }
        }
    }
}

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
    @State private var disabled: Bool = false

    private var dismissButton: some View {
        Button("Cancel", role: .cancel) {
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


    var body: some View {
        let view = VStack(alignment: .center) {
            if controller.stalledConnection {
                StalledView()
            } else {
                Spacer()
                RotatingTaler(size: 100,
                          progress: true,                 // VoiceOver "In progress"
                              once: false,
                        background: developerMode ? .blue : nil,
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
        .padding()
        .talerFont(.title)
        .navigationTitle(navTitle)
        .background(FullBackground())

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
