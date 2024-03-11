//
//  ErrorSheet.swift
//  TalerWallet
//
//  Created by Ivan Avalos on 08/03/24.
//  Copyright © 2024 Taler. All rights reserved.
//

import SwiftUI

enum ErrorData {
case user(String)
case developer(String)
case taler(WalletBackendResponseError)
}

struct ErrorSheet: View {
    var message: String
    var copyable: Bool

    var onDismiss: () -> Void

    let navTitle = String(localized: "Error")
    let unknownError = String(localized: "Unknown error")

    init(message: String, copyable: Bool, onDismiss: @escaping () -> Void) {
        self.message = message
        self.copyable = copyable
        self.onDismiss = onDismiss
    }

    init(error: WalletBackendResponseError, developerMode: Bool, onDismiss: @escaping () -> Void) {
        if let json = error.toJSON(), developerMode {
            self.init(message: json, copyable: true, onDismiss: onDismiss)
        } else {
            self.init(message: error.message, copyable: false, onDismiss: onDismiss)
        }
    }

    init(data: ErrorData, developerMode: Bool, onDismiss: @escaping () -> Void) {
        switch data {
        case .user(let message):
            self.init(message: message, copyable: false, onDismiss: onDismiss)
            return
        case .developer(let message):
            self.init(message: message, copyable: true, onDismiss: onDismiss)
            return
        case .taler(let error):
            self.init(error: error, developerMode: developerMode, onDismiss: onDismiss)
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
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
        }.safeAreaInset(edge: .bottom) {
            Button("Cancel", role: .cancel) {
                onDismiss()
            }
            .buttonStyle(TalerButtonStyle(type: .bordered))
            .padding(.bottom)
            .padding(.horizontal)
        }
    }
}

struct ErrorSheet_Previews: PreviewProvider {
    static let error = WalletBackendResponseError(
        talerErrorCode: 7025,
        talerErrorHint: "A KYC step is required before withdrawal can proceed",
        message: "A KYC step is required before withdrawal can proceed")

    static var previews: some View {
        ErrorSheet(error: error, developerMode: true, onDismiss: {})
        ErrorSheet(error: error, developerMode: false, onDismiss: {})
    }
}
