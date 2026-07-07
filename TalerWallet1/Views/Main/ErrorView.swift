/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Iván Ávalos
 */
import SwiftUI
import taler_swift

enum ErrorData {
    case message(title: String, message: String)
    case error(Error)
}

struct ErrorView: View {
    let stack: CallStack
    var title: String
    var message: String? = nil
    var requestUrl: String? = nil
    var copyable: Bool

    @State var isCopied: Bool = false

    var onDismiss: () -> Void

    init(_ stack: CallStack, title: String, message: String? = nil,
      requestUrl: String? = nil, copyable: Bool, onDismiss: @escaping () -> Void) {
        self.stack = stack
        self.title = title
        self.message = message
        self.requestUrl = requestUrl
        self.copyable = copyable
        self.onDismiss = onDismiss
    }

    init(_ stack: CallStack, error: Error, devMode: Bool, onDismiss: @escaping () -> Void) {
        let internetError = String(localized: "Network problem")
        let internetMessage = String(localized: "Please check your internet connection and try again.")
        let walletCoreError = String(localized: "Internal core error")
        let initializationError = String(localized: "Initialization error")
        let serializationError = String(localized: "Serialization error")
        let deserializationError = String(localized: "Deserialization error")
        let unknownError = String(localized: "Unknown error")

        switch error {
            case let walletError as WalletBackendError:
                switch walletError {
                    case .walletCoreError(let walletBackendResponseError):
                        if let responseError = walletBackendResponseError {
                            let code = responseError.code
                            if code == 7002 || code == 7032 {
                                self.init(stack,
                                    title: internetError,
                                  message: responseError.hint ?? internetMessage,
                               requestUrl: responseError.requestUrl,
                                 copyable: false,
                                onDismiss: onDismiss)
                                break
                            }
                            // for now, always show JSON and allow to copy it
                            if let json = responseError.toJSON() {
                                self.init(stack, title: walletCoreError, message: json, copyable: true, onDismiss: onDismiss)
                                break
//                            } else if let hint = responseError.errorResponse?.hint ?? responseError.hint {
//                                self.init(stack, title: walletCoreError, message: hint, copyable: true, onDismiss: onDismiss)
//                                break
//                            } else if let message = responseError.message {
//                                self.init(stack, title: walletCoreError, message: message, copyable: true, onDismiss: onDismiss)
//                                break
                            }
                        }
                        self.init(stack, title: walletCoreError, copyable: false, onDismiss: onDismiss)
                    case .initializationError:
                        self.init(stack, title: initializationError, copyable: false, onDismiss: onDismiss)
                    case .serializationError:
                        self.init(stack, title: serializationError, copyable: false, onDismiss: onDismiss)
                    case .deserializationError:
                        self.init(stack, title: deserializationError, copyable: false, onDismiss: onDismiss)
                }
            default:
                self.init(stack, title: unknownError, message: error.localizedDescription, copyable: false, onDismiss: onDismiss)
        }
    }

    init(_ stack: CallStack, data: ErrorData, devMode: Bool, onDismiss: @escaping () -> Void) {
        switch data {
            case .message(let title, let message):
                self.init(stack, title: title, message: message, copyable: false, onDismiss: onDismiss)
            case .error(let error):
                self.init(stack, error: error, devMode: devMode, onDismiss: onDismiss)
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                Image(systemName: EXCLAMATION)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(WalletColors().attention)
                    .padding()

                Text(title)
                    .talerFont(.title)
                    .padding(.bottom)

                if let message {
                    if copyable {
                        if #available(iOS 16.4, *) {
                            Text(message).monospaced()
                        } else {
                            Text(message).font(.system(.body, design: .monospaced))
                        }

                        CopyButton(textToCopy: message, isCopied: $isCopied, vertical: false)
                            .accessibilityLabel(Text("Copy the error JSON", comment: "a11y"))
                            .padding()
                    } else {
                        if let requestUrl {
                            Text(requestUrl)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        Text(message)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            Button("OK", role: .cancel) {
                onDismiss()
            }
            .buttonStyle(TalerButtonStyle(type: .bordered))
            .padding(.bottom)
            .padding(.horizontal)
        }
    }
}
