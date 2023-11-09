/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation

struct TransactionButton: View {
    let transactionId : String
    let command : TxAction
    let action: (_ transactionId: String) async throws -> Void

    @State var disabled: Bool = false
    @State var executed: Bool = false
    var body: some View {
        let isDestructive = (command == .delete) || (command == .fail)
        let isCancel = (command == .abort)
        let role: ButtonRole? = isDestructive ? .destructive
                              : isCancel      ? .cancel
                                              : nil
        Button(role: role, action: {
            if !disabled {
                disabled = true     // don't try this more than once
                Task { // runs on MainActor
                    do {
                        try await action(transactionId)
//                    symLog.log("\(executed) \(transactionId)")
                        executed = true
                    } catch {    // TODO: error
//                    symLog.log(error.localizedDescription)
                    }
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
            .accessibilityFont(.title2)
            .frame(maxWidth: .infinity)
        })
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
    }
}
// MARK: -
#if DEBUG
struct TransactionButton_Previews: PreviewProvider {

    static func action(_ transactionId: String) async throws {
        print(transactionId)
    }

    static var previews: some View {
        List {
            TransactionButton(transactionId: "Button pressed", command: .abort, action: action)
        }
    }
}
#endif
