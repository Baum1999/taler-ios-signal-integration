/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct PendingOpsListView: View {
    private let symLog = SymLogV(0)
    let navTitle = String(localized: "Pending")

    @State var pendingOperations: [PendingOperation] = []
    var model: PendingModel

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let reloadAction = model.getPendingOperationsM
        Content(symLog: symLog, pendingOperations: $pendingOperations, reloadAction: reloadAction)
            .navigationTitle(navTitle)
            .task {
                symLog.log(".task")
                pendingOperations = await reloadAction()
            }
    }
}
// MARK: -
extension PendingOpsListView {
    struct Content: View {
        let symLog: SymLogV?
        @Binding var pendingOperations: [PendingOperation]
        var reloadAction: () async -> [PendingOperation]
        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            ScrollViewReader { scrollView in
                List(pendingOperations, id: \.self) { pendingOp in
                    PendingOpView(pendingOp: pendingOp)
                }
                .listStyle(SidebarListStyle())
                .navigationBarTitleDisplayMode(.large)
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_PENDING)
                }
                .refreshable {
                    symLog?.log("refreshing")
                    pendingOperations = await reloadAction()
                }
            }
        }
    }
}
