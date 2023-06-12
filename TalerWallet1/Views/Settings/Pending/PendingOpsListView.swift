/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct PendingOpsListView: View {
    private let symLog = SymLogV(0)
    let navTitle = String(localized: "Pending")

    @ObservedObject var model: PendingModel

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let reloadAction = model.updateM
        Content(symLog: symLog, model: model, reloadAction: reloadAction)
            .navigationTitle(navTitle)
            .task {
                symLog.log(".task")
                do {
                    try await reloadAction()
                } catch {    // TODO: show error
                    symLog.log(error.localizedDescription)
                }
            }
    }
}
// MARK: -
extension PendingOpsListView {
    struct Content: View {
        let symLog: SymLogV?
        @ObservedObject var model: PendingModel
        var reloadAction: () async throws -> ()

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            ScrollViewReader { scrollView in
                List(model.pendingOperations, id: \.self) { pendingOp in
                    PendingOpView(pendingOp: pendingOp)
                }
                .listStyle(SidebarListStyle())
                .navigationBarTitleDisplayMode(.large)
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_PENDING)
                }
                .refreshable {
                    do {
                        symLog?.log("refreshing")
                        try await reloadAction()
                    } catch {    // TODO: error
                        symLog?.log(error.localizedDescription)
                    }
                }
            }
        }
    }
}
