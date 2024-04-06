/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation

struct TransactionButton: View {
    let transactionId: String
    let command: TxAction
    let warning: String?
    let action: (_ transactionId: String, _ viewHandles: Bool) async throws -> Void

    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true

    @State private var disabled: Bool = false
    @State private var executed: Bool = false
    @State private var showAlert: Bool = false

    private func doAction() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
            if let _ = try? await action(transactionId, false) {
//                symLog.log("\(executed) \(transactionId)")
                executed = true
            }
        }
    }

    var body: some View {
        let isDestructive = (command == .delete) || (command == .fail)
        let isCancel = (command == .abort)
        let role: ButtonRole? = isDestructive ? .destructive
                              : isCancel      ? .cancel
                                              : nil
        Button(role: role, action: {
            if !disabled {
                if shouldShowWarning && (isDestructive || isCancel) {
                    showAlert = true
                } else {
                    doAction()
                }
            }
        }, label: {
            HStack(spacing: 50) {
                Text(executed ? command.localizedActionExecuted
                              : command.localizedActionTitle)
                if let imageName = command.localizedActionImage {
                    Image(systemName: imageName)
                }
            }
            .talerFont(.title2)
            .frame(maxWidth: .infinity)
        })
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
        .alert(warning ?? EMPTYSTRING, isPresented: $showAlert, actions: {
                Button("Cancel", role: .cancel) {
                    showAlert = false
                }
                Button(command.localizedActionTitle) {
                    showAlert = false
                    doAction()
                }
            }, message: { Text("This operation cannot be undone") }
        )
    }
}
// MARK: -
#if DEBUG
struct TransactionButton_Previews: PreviewProvider {

    static func action(_ transactionId: String, _ viewHandles: Bool) async throws {
        print(transactionId)
    }

    static var previews: some View {
        List {
            TransactionButton(transactionId: "Button pressed", command: .abort,
                              warning: "Are you sure you want to abort this transaction?",
                              action: action)
        }
    }
}
#endif
