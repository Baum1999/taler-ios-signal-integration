/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

enum ErrorData {
case message(String)
case error(Error)
}

struct ErrorSheet: View {
    var message: String
    var copyable: Bool

    var onDismiss: () -> Void

    init(message: String, copyable: Bool, onDismiss: @escaping () -> Void) {
        self.message = message
        self.copyable = copyable
        self.onDismiss = onDismiss
    }

    init(error: Error, devMode: Bool, onDismiss: @escaping () -> Void) {
        let walletCoreError = String(localized: "Internal core error")
        let initializationError = String(localized: "Initialization error")
        let serializationError = String(localized: "Serialization error")
        let deserializationError = String(localized: "Deserialization error")

        switch error {
        case let walletError as WalletBackendError:
            switch walletError {
            case .walletCoreError(let error):
                if let json = error?.toJSON(), devMode {
                    self.init(message: json, copyable: true, onDismiss: onDismiss)
                } else if let message = error?.message {
                    self.init(message: message, copyable: false, onDismiss: onDismiss)
                } else {
                    self.init(message: walletCoreError, copyable: false, onDismiss: onDismiss)
                }
            case .initializationError:
                self.init(message: initializationError, copyable: false, onDismiss: onDismiss)
            case .serializationError:
                self.init(message: serializationError, copyable: false, onDismiss: onDismiss)
            case .deserializationError:
                self.init(message: deserializationError, copyable: false, onDismiss: onDismiss)
            }
        default:
            self.init(message: error.localizedDescription, copyable: false, onDismiss: onDismiss)
        }
    }

    init(data: ErrorData, devMode: Bool, onDismiss: @escaping () -> Void) {
        let unknownError = String(localized: "Unknown error")

        switch data {
        case .message(let message):
            self.init(message: message, copyable: false, onDismiss: onDismiss)
            return
        case .error(let error):
            self.init(error: error, devMode: devMode, onDismiss: onDismiss)
            return
        }

        self.init(message: unknownError, copyable: false, onDismiss: onDismiss)
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(.red)
                            .padding(.bottom)

                        Text("There was an error!")
                            .talerFont(.title)
                            .padding(.bottom)

                        if copyable {
                            if #available(iOS 16.4, *) {
                                Text(message).monospaced()
                            } else {
                                Text(message).font(.system(.body, design: .monospaced))
                            }

                            CopyButton(textToCopy: message, vertical: false)
                                .accessibilityLabel("Copy the error JSON")
                                .padding(.top)
                        } else {
                            Text(message)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }.safeAreaInset(edge: .bottom) {
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
        code: 7025,
        hint: "A KYC step is required before withdrawal can proceed",
        message: "A KYC step is required before withdrawal can proceed"))

    static var previews: some View {
        ErrorSheet(error: error, devMode: true, onDismiss: {})
        ErrorSheet(error: error, devMode: false, onDismiss: {})
    }
}
