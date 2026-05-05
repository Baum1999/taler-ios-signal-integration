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
    var copyable: Bool

    @State var isCopied: Bool = false

    var onDismiss: () -> Void

    init(_ stack: CallStack, title: String, message: String? = nil, copyable: Bool, onDismiss: @escaping () -> Void) {
        self.stack = stack
        self.title = title
        self.message = message
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
                            if responseError.code == 7001 {
                                self.init(stack, title: internetError, message: internetMessage, copyable: false, onDismiss: onDismiss)
                                break
                            }
                        }
                        if let json = walletBackendResponseError?.toJSON(), devMode {
                            self.init(stack, title: walletCoreError, message: json, copyable: true, onDismiss: onDismiss)
                        } else if let hint = walletBackendResponseError?.errorResponse?.hint ?? walletBackendResponseError?.hint {
                            self.init(stack, title: walletCoreError, message: hint, copyable: false, onDismiss: onDismiss)
                        } else if let message = walletBackendResponseError?.message {
                            self.init(stack, title: walletCoreError, message: message, copyable: false, onDismiss: onDismiss)
                        } else {
                            self.init(stack, title: walletCoreError, copyable: false, onDismiss: onDismiss)
                        }
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
                        Text(message)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            Button("Close", role: .cancel) {
                onDismiss()
            }
            .buttonStyle(TalerButtonStyle(type: .bordered))
            .padding(.bottom)
            .padding(.horizontal)
        }
    }
}
