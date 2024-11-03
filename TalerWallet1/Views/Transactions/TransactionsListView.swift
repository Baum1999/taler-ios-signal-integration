/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

#if DEBUG
fileprivate let showUpDown = 8      // show up+down buttons in the menubar if list has many lines
#else
fileprivate let showUpDown = 25     // show up+down buttons in the menubar if list has many lines
#endif
struct TransactionsListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    let balance: Balance                            // this is the currency to be used
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    let navTitle: String?

    @Binding var transactions: [Transaction]

    let reloadAllAction: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)

    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var viewId = UUID()

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let count = transactions.count
        ScrollViewReader { scrollView in
            List {
                TransactionsArraySliceV(symLog: symLog,
                                         stack: stack.push(),
                                         scope: scope,
                                  transactions: $transactions,
                               reloadAllAction: reloadAllAction,
                               reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            }
            .id(viewId)
            .listStyle(myListStyle.style).anyView
#if REFRESHABLE
            .refreshable {
                controller.hapticNotification(.success)
                symLog.log("refreshing")
                await reloadAllAction(stack.push())
            }
#endif
            .if(count > showUpDown) { view in
                view.navigationBarItems(trailing: HStack {
                    ArrowUpButton {
//                        print("up")
                        withAnimation { scrollView.scrollTo(0) }
                    }
                    ArrowDownButton {
//                        print("down")
                        withAnimation { scrollView.scrollTo(transactions.count - 1) }
                    }
                })
            }
        } // ScrollViewReader
        .navigationTitle(navTitle ?? scope.currency)
        .accessibilityHint(String(localized: "Transaction list"))
        .task {
            symLog.log("❗️.task List❗️")
            await reloadAllAction(stack.push())
        }
        .overlay {
            if transactions.isEmpty {
                TransactionsEmptyView(stack: stack.push(), currency: scope.currency)
            }
        }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONLIST, stack: stack.push())
            selectedBalance = balance           // balance fixed for send/request/deposit/withdraw
        }
    }
}
// MARK: -
// used by TransactionsListView, and by BalancesSectionView to show the last 3 transactions
struct TransactionsArraySliceV: View {
    let symLog: SymLogV?
    let stack: CallStack
    let scope: ScopeInfo
    @Binding var transactions: [Transaction]
    let reloadAllAction: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)

    @EnvironmentObject private var model: WalletModel

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let abortAction = model.abortTransaction
        let deleteAction = model.deleteTransaction
        let failAction = model.failTransaction
        let suspendAction = model.suspendTransaction
        let resumeAction = model.resumeTransaction

        ForEach(transactions, id: \.self) { transaction in
            let destination = TransactionSummaryV(stack: stack.push(),
                                                  scope: scope,
                                          transactionId: transaction.id,
                                           reloadAction: reloadOneAction,
                                               navTitle: nil,
                                                hasDone: false,
                                            abortAction: abortAction,
                                           deleteAction: deleteAction,
                                             failAction: failAction,
                                          suspendAction: suspendAction,
                                           resumeAction: resumeAction)
            let row = NavigationLink { destination } label: {
                TransactionRowView(scope: scope, transaction: transaction)
            }.id(transaction.id)
            if transaction.isDeleteable {
                row.swipeActions(edge: .trailing) {
                        Button {
                            symLog?.log("deleteAction")
                            Task { // runs on MainActor
                                let _ = try? await deleteAction(transaction.id, false)
                                await reloadAllAction(stack.push())
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            } else {
                row
            }
        }
    }
}
