/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Iván Ávalos
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

enum BannerType {
    case error
    case networkUnavailable
    case warning5sec
}

struct ErrorBanner: View {
    let type: BannerType
    
    init(_ type: BannerType) {
        self.type = type
    }

    var errorText: String {
        switch type {
            case .error:
                return "An error occurred…"
            case .networkUnavailable:
                return "Network unavailable!"
            case .warning5sec:
                return "Network is slow…"
        }
    }

    var errorColor: Color {
        switch type {
            case .error:
                return .red
            case .networkUnavailable:
                return .red
            case .warning5sec:
                return .yellow
        }
    }

    var body: some View {
        let text = Text(errorText)
            .foregroundStyle(.white)
            .talerFont(.title2)
        Group {
            if #available(iOS 26.0, *) {
                ContainerRelativeShape()
                    .fill(errorColor)
                    .frame(height: 80)
                    .overlay {
                        ZStack {
                            VStack(spacing: 0) {
                                Color.clear
                                Rectangle()
                                    .fill(errorColor)
                            }
                            text
                        }
                    }
            } else {
                text
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 80)
                    .background {
                        let radius = 12.0
                        if #available(iOS 16.4, *) {
                            let radii = RectangleCornerRadii(topLeading: radius,
                                                          bottomLeading: 0,
                                                         bottomTrailing: 0,
                                                            topTrailing: radius)
                            UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
                                .fill(errorColor)
                        } else {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(errorColor)
                                .overlay {
                                    VStack(spacing: 0) {
                                        Color.clear
                                        Rectangle()
                                            .fill(errorColor)
                                    }
                                }
                        }
                    }
            }
        }
            .transition(.asymmetric(
                insertion: .move(edge: .top),
                removal: .move(edge: .top)
            ))
    }
}

enum ErrorData {
    case message(title: String, message: String)
    case error(Error)
}

struct ErrorView: View {
    let stack: CallStack?
    var title: String
    var exclam: Bool
    var message: String? = nil
    var requestUrl: String? = nil
    var copyable: Bool

    var onDismiss: (() -> Void)?

    init(_ stack: CallStack?, title: String, exclam: Bool = true, message: String? = nil,
         requestUrl: String? = nil, copyable: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.stack = stack
        self.title = title
        self.exclam = exclam
        self.message = message
        self.requestUrl = requestUrl
        self.copyable = copyable
        self.onDismiss = onDismiss
    }

    init(_ stack: CallStack?, error: Error, devMode: Bool, onDismiss: (() -> Void)? = nil) {
        let internetError = String(localized: "Network problem")
        let internetMessage = String(localized: "Please check your internet connection and try again.")
        let walletCoreError = String(localized: "Internal core error")
        let initializationError = String(localized: "Initialization error")
        let serializationError = String(localized: "Serialization error")
        let deserializationError = String(localized: "Deserialization error")
        let unknownError = String(localized: "Unknown error")
        let userCancelled = String(localized: "User cancelled")
        let transactionError = String(localized: "Transaction Error")

        switch error {
            case let walletError as WalletBackendError:
                switch walletError {
                    case .walletCoreError(let walletBackendResponseError):
                        if let responseError = walletBackendResponseError {
                            let code = responseError.code
                            if code == 7002 || code == 7003 || code == 7005 || code == 7032 || code == 7036 || code == 7049 {
                                self.init(stack,
                                    title: code == 7036 ? userCancelled
                                         : code == 7049 ? transactionError : internetError,
                                   exclam: code != 7036 && code != 7049,
                                  message: responseError.hint ?? internetMessage,
                               requestUrl: responseError.requestUrl,
                                 copyable: false,
                                onDismiss: onDismiss)
                                break
                            }
                            let hint = responseError.errorResponse?.hint ?? responseError.hint      // nested one preferred
                            if !devMode, let hint {
                                // prefer hint for regular users
                                self.init(stack, title: walletCoreError, message: hint, copyable: true, onDismiss: onDismiss)
                                break
                            }
                            if let json = responseError.toJSON() {
                                // raw JSON for developers, or if there is no hint
                                self.init(stack, title: walletCoreError, message: json, copyable: true, onDismiss: onDismiss)
                                break
                            } else if let hint {
                                // should never happen
                                self.init(stack, title: walletCoreError, message: hint, copyable: true, onDismiss: onDismiss)
                                break
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

    init(_ stack: CallStack?, data: ErrorData, devMode: Bool, onDismiss: (() -> Void)? = nil) {
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
                if exclam {
                    Image(systemName: EXCLAMATION)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(WalletColors().attention)
                        .padding()
                }
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

                        CopyButton(message, vertical: false)
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
                if let onDismiss {
                    onDismiss()
                } else {
                    dismissTop(stack?.push())
                }
            }
            .buttonStyle(TalerButtonStyle(type: .bordered))
            .padding(.bottom)
            .padding(.horizontal)
        }
    }
}
