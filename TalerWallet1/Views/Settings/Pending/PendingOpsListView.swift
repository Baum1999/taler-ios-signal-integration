/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct PendingOpsListView: View {
    let navTitle = String(localized: "Pending")
    let stack: CallStack

    @EnvironmentObject private var model: WalletModel

    @State var pendingOperations: [PendingOperation] = []

    var body: some View {
        let reloadAction = model.getPendingOperationsM
        Content(stack: stack.push(), pendingOperations: $pendingOperations, reloadAction: reloadAction)
            .navigationTitle(navTitle)
            .task {
                pendingOperations = await reloadAction()
            }
    }
}
// MARK: -
extension PendingOpsListView {
    struct Content: View {
        let stack: CallStack
        @Binding var pendingOperations: [PendingOperation]
        var reloadAction: () async -> [PendingOperation]
        @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
        var body: some View {
//            ScrollViewReader { scrollView in
                List(pendingOperations, id: \.self) { pendingOp in
                    PendingOpView(pendingOp: pendingOp)
                }
                .listStyle(myListStyle.style).anyView
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_PENDING, stack: stack.push())
                }
                .refreshable {
                    pendingOperations = await reloadAction()
                }
//            }
        }
    }
}
