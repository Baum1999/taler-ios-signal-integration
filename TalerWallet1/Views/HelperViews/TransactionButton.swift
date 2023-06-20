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
        let role: ButtonRole? = (command == .abort) ? .cancel
                              : (command == .delete) ? .destructive
                                                     : nil
        Button(role: role, action: {
            Task {
                disabled = true     // don't try this more than once
                do {
                    try await action(transactionId)
//                    symLog.log("\(executed) \(transactionId)")
                    executed = true
                } catch {    // TODO: error
//                    symLog.log(error.localizedDescription)
                }
            }
        }, label: {
            HStack {
                if executed {
                    switch command {
                        case .delete:
                            Text("Deleted from list")
                        case .abort:
                            Text("Abort pending...")
                        case .fail:
                            Text("Failing...")
                        case .suspend:
                            Text("Suspending...")
                        case .resume:
                            Text("Resuming...")
                    }
                } else {
                    let spaces = "        "
                    switch command {
                        case .delete:
                            Text("Delete from list" + spaces)
                            Image(systemName: "trash")                  // 􀈑
                        case .abort:
                            Text("Abort" + spaces)
                            Image(systemName: "x.circle")               // 􀀲
                        case .fail:
                            Text("Fail" + spaces)
                            Image(systemName: "fanblades.slash")        // 􁝚
                        case .suspend:
                            Text("Suspend" + spaces)
                            Image(systemName: "clock.badge.xmark")      // 􁜒
                        case .resume:
                            Text("Resume" + spaces)
                            Image(systemName: "clock.arrow.circlepath") // 􀣔
                    }
                }
            }
            .font(.title)
            .frame(maxWidth: .infinity)
        })
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal)
        .disabled(disabled)
    }

}


#if DEBUG
struct TransactionButton_Previews: PreviewProvider {

    static var previews: some View {
        List {
            TransactionButton(transactionId: "String", command: .abort, action: {transactionId in })
        }
    }
}
#endif
