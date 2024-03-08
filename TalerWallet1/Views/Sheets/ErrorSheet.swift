//
//  ErrorSheet.swift
//  TalerWallet
//
//  Created by Ivan Avalos on 08/03/24.
//  Copyright © 2024 Taler. All rights reserved.
//

import SwiftUI

struct ErrorSheet: View {
    var message: String
    var copyable: Bool

    var onDismiss: () -> Void

    let navTitle = String(localized: "Error")

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

    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.red)
                    .padding(.bottom)

                if copyable {
                    if #available(iOS 16.4, *) {
                        Text(message)
                            .foregroundStyle(.red)
                            .monospaced()
                    } else {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.system(.body, design: .monospaced))
                    }

                    CopyButton(textToCopy: message, vertical: false)
                        .accessibilityLabel("Copy the error JSON")
                        .padding(.top)
                } else {
                    Text(message)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle")
                    }
                }
            }
            .padding()
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
