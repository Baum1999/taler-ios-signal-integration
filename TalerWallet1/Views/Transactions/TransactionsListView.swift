/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct TransactionsListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    let navTitle: String

    let scopeInfo: ScopeInfo
    let transactions: [Transaction]
    let showUpDown: Bool
    let reloadAllAction: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)

    @State private var viewId = UUID()
    @State private var upAction: () -> Void = {}
    @State private var downAction: () -> Void = {}
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
                                     scopeInfo: scopeInfo,
                                  transactions: transactions,
                               reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            }
            .id(viewId)
            .listStyle(myListStyle.style).anyView
#if REFRESHABLE
            .refreshable {
                symLog.log("refreshing")
                await reloadAllAction(stack.push())
            }
#endif
            .navigationBarItems(trailing: HStack {
                if showUpDown {
                    ArrowUpButton(action: upAction)
                    ArrowDownButton(action: downAction)
                } else {
                    EmptyView()
                }
            })
            .onAppear {
                if showUpDown {
                    upAction = {
                        withAnimation { scrollView.scrollTo(0) }
                    }
                    downAction = {
                        withAnimation { scrollView.scrollTo(transactions.count - 1) }
                    }
//                    downAction()
                }
            }
        } // ScrollView
        .navigationTitle(navTitle)
        .accessibilityHint(String(localized: "Transaction list"))
        .task {
            symLog.log(".task ")
            await reloadAllAction(stack.push())
        }
        .overlay {
            if transactions.isEmpty {
                TransactionsEmptyView(stack: stack.push(), currency: scopeInfo.currency)
            }
        }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_TRANSACTIONLIST, stack: stack.push())
        }
    }
}
// MARK: -
// used by TransactionsListView, and by BalancesSectionView to show the last 3 transactions
struct TransactionsArraySliceV: View {
    let symLog: SymLogV?
    let stack: CallStack
    let scopeInfo: ScopeInfo
    let transactions: [Transaction]
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
        ForEach(Array(zip(transactions.indices, transactions)), id: \.1) { index, transaction in
            NavigationLink {
                LazyView {
                    TransactionSummaryV(stack: stack.push(),
                                  transactionId: transaction.id,
                                   reloadAction: reloadOneAction,
                                       navTitle: nil,
                                     doneAction: nil,
                                    abortAction: abortAction,
                                   deleteAction: deleteAction,
                                     failAction: failAction,
                                  suspendAction: suspendAction,
                                   resumeAction: resumeAction)
                }
            } label: {
                TransactionRowView(transaction: transaction)
            }
            .id(Int(index))
        }
    }
}
