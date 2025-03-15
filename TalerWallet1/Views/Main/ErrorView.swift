/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
    var title: String
    var message: String? = nil
    var copyable: Bool

    var onDismiss: () -> Void

    init(title: String, message: String? = nil, copyable: Bool, onDismiss: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.copyable = copyable
        self.onDismiss = onDismiss
    }

    init(error: Error, devMode: Bool, onDismiss: @escaping () -> Void) {
        let walletCoreError = String(localized: "Internal core error")
        let initializationError = String(localized: "Initialization error")
        let serializationError = String(localized: "Serialization error")
        let deserializationError = String(localized: "Deserialization error")
        let unknownError = String(localized: "Unknown error")

        switch error {
        case let walletError as WalletBackendError:
            switch walletError {
            case .walletCoreError(let error):
                if let json = error?.toJSON(), devMode {
                    self.init(title: walletCoreError, message: json, copyable: true, onDismiss: onDismiss)
                } else if let hint = error?.errorResponse?.hint ?? error?.hint {
                    self.init(title: walletCoreError, message: hint, copyable: false, onDismiss: onDismiss)
                } else if let message = error?.message {
                    self.init(title: walletCoreError, message: message, copyable: false, onDismiss: onDismiss)
                } else {
                    self.init(title: walletCoreError, copyable: false, onDismiss: onDismiss)
                }
            case .initializationError:
                self.init(title: initializationError, copyable: false, onDismiss: onDismiss)
            case .serializationError:
                self.init(title: serializationError, copyable: false, onDismiss: onDismiss)
            case .deserializationError:
                self.init(title: deserializationError, copyable: false, onDismiss: onDismiss)
            }
        default:
            self.init(title: unknownError, message: error.localizedDescription, copyable: false, onDismiss: onDismiss)
        }
    }

    init(data: ErrorData, devMode: Bool, onDismiss: @escaping () -> Void) {
        switch data {
            case .message(let title, let message):
                self.init(title: title, message: message, copyable: false, onDismiss: onDismiss)
            case .error(let error):
                self.init(error: error, devMode: devMode, onDismiss: onDismiss)
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                Image(systemName: "exclamationmark.circle")
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

                        CopyButton(textToCopy: message, vertical: false)
                            .accessibilityLabel("Copy the error JSON")
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

struct ErrorSheet_Previews: PreviewProvider {
    static let error = WalletBackendError.walletCoreError(WalletBackendResponseError(
        code: 7025, when: Timestamp.now(),
        hint: "A KYC step is required before withdrawal can proceed",
        message: "A KYC step is required before withdrawal can proceed"))

    static var previews: some View {
        ErrorView(error: error, devMode: true, onDismiss: {})
        ErrorView(error: error, devMode: false, onDismiss: {})
    }
}
