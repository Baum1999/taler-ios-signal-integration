/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation

struct WarningButton: View {
    let warningText: String?
    let buttonTitle: String
    let buttonIcon: String?
    let role: ButtonRole?
    @Binding var disabled: Bool
    let action: () -> Void

    @AppStorage("shouldShowWarning") var shouldShowWarning: Bool = true
    @State private var showAlert: Bool = false

    var body: some View {
        Button(role: role,
             action: {
                if !disabled {
                    if shouldShowWarning && (role == .destructive || role == .cancel) {
                        showAlert = true
                    } else {
                        action()
                    }
                }
        }) {
            HStack(spacing: 50) {
                Text(buttonTitle)
                if let buttonIcon {
                    Image(systemName: buttonIcon)
                }
            }
        }
        .talerFont(.title2)
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
        .alert(warningText ?? EMPTYSTRING, isPresented: $showAlert, actions: {
                Button("Cancel", role: .cancel) {
                    showAlert = false
                }
                Button(buttonTitle) {
                    showAlert = false
                    action()
                }
            }, message: { Text("This operation cannot be undone") }
        )
    }
}
// MARK: -
struct TransactionButton: View {
    let transactionId: String
    let command: TxAction
    let warning: String?
    @Binding var didExecute: Bool
    let action: (_ transactionId: String, _ viewHandles: Bool) async throws -> Void

    @State private var disabled: Bool = false
    @State private var executed: Bool = false
    @State private var buttonTitle: String = EMPTYSTRING

    private func doAction() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
            if let _ = try? await action(transactionId, false) {
//                symLog.log("\(executed) \(transactionId)")
                executed = true             // change button text
                didExecute = true
            }
        }
    }

    var body: some View {
        let isDestructive = (command == .delete) || (command == .fail)
        let isCancel = (command == .abort)
        let role: ButtonRole? = isDestructive ? .destructive
                              : isCancel      ? .cancel
                                              : nil
        let buttonTitle = executed ? command.localizedActionExecuted
                                   : command.localizedActionTitle
        WarningButton(warningText: warning,
                      buttonTitle: command.localizedActionTitle,
                       buttonIcon: command.localizedActionImage,
                             role: role,
                         disabled: $disabled,
                           action: doAction)
    }
}
// MARK: -
#if DEBUG
//struct TransactionButton_Previews: PreviewProvider {
//
//    static func action(_ transactionId: String, _ viewHandles: Bool) async throws {
//        print(transactionId)
//    }
//
//    static var previews: some View {
//        List {
//            TransactionButton(transactionId: "Button pressed", command: .abort,
//                              warning: "Are you sure you want to abort this transaction?",
//                              didExecute: <#Binding<Bool>#>,
//                              action: action)
//        }
//    }
//}
#endif
