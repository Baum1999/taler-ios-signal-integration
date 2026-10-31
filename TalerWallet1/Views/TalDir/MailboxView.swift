/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows the messages
struct MailboxView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var created: Bool = false
    @State private var progress: Double = 0
    @State private var isCancelled: Bool = false

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
//            showRestoreAlert = false
//            withAnimation { selectedBackup = nil }
        }
    }

    @ViewBuilder func messageRowV(_ message: MailboxMessage) -> some View {
        VStack(alignment: .leading) {
            Text(message.talerUri)
                .talerFont(.body)
            let (dateString, date) = TalerDater.dateString(message.downloadedAt, minimalistic)
            let a11yDate = TalerDater.accessibilityDate(date) ?? dateString
            Text(dateString)
                .talerFont(.body)
                .accessibilityLabel(a11yDate)
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        List {
            let messages = controller.messages
            Section {
                if messages.isEmpty {
                    Text("No messages yet...")
                } else {
                    ForEachWithIndex(array: messages) { index, message in
                        messageRowV(message)
                    }
                }
            }
        }
        .listStyle(myListStyle.style).anyView
        .navigationTitle(navTitle)
        .refreshable {
            controller.hapticNotification(.success)
            symLog.log("refreshing")
            await controller.refreshMailbox(stack.push())
        }
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_MAILBOX, stack: stack.push())
        }
    } // body
}
