/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct TransactionsListView: View {
    private let symLog = SymLogV(0)
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    let navTitle: String

    let currency: String
    let transactions: [Transaction]
    let showUpDown: Bool
    let reloadAllAction: () async -> ()
    let reloadOneAction: ((_ transactionId: String) async throws -> Transaction)

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let count = transactions.count
        // TODO: Unlock the power of grammatical agreement
//        let title = AttributedString(localized: "^[\(count) Ticket](inflect: true)")
//        let title: String = "\(count) \(navTitle)"
        Content(symLog: symLog,
              currency: currency,
          transactions: transactions,
            showUpDown: showUpDown,
           myListStyle: $myListStyle,
       reloadAllAction: reloadAllAction,
       reloadOneAction: reloadOneAction)
//            .navigationTitle(title)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)      // .inline
            .onAppear {
                DebugViewC.shared.setViewID(VIEW_TRANSACTIONLIST)
            }
            .task {
                symLog.log(".task ")
                await reloadAllAction()
            }
    }
}
// MARK: -
extension TransactionsListView {
    struct Content: View {
        let symLog: SymLogV?
        let currency: String
        let transactions: [Transaction]
        let showUpDown: Bool
        @Binding var myListStyle: MyListStyle
        let reloadAllAction: () async -> ()
        let reloadOneAction: ((_ transactionId: String) async throws -> Transaction)

        @EnvironmentObject private var model: WalletModel

        @State private var upAction: () -> Void = {}
        @State private var downAction: () -> Void = {}

//        func removeItems(at offsets: IndexSet) {
//            let transactions = model.transactions
//            var idsToDelete: [String] = []
//            for n in offsets {  // save IDs of transactions
//                let common = transactions[n].common
//                idsToDelete.append(common.transactionId)
//            }
//            // then remove items from the list model (and the view)
//            model.transactions.remove(atOffsets: offsets)
//            // finally tell wallet-core to delete the saved IDs
//            Task {  // delete this transaction from wallet-core
//                for transactionId in idsToDelete {
//                    do {
//                        try await deleteAction(transactionId)
//                        symLog?.log("deleted \(transactionId)")
//                    } catch {    // TODO: error
//                        symLog?.log(error.localizedDescription)
//                    }
//                }
//            }
//        }

        @State var viewId = UUID()
        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            let abortAction = model.abortTransaction
            let deleteAction = model.deleteTransaction
            let failAction = model.failTransaction
            let suspendAction = model.suspendTransaction
            let resumeAction = model.resumeTransaction
            ScrollViewReader { scrollView in
                List {
                    ForEach(Array(zip(transactions.indices, transactions)), id: \.1) { index, transaction in
                        NavigationLink { LazyView {        // whole row like in a tableView
                            // pending may not be deleted, but only aborted
                            TransactionDetailView(transactionId: transaction.id,
                                                 reloadAction: reloadOneAction,
                                                  abortAction: abortAction,
                                                 deleteAction: deleteAction,
                                                   failAction: failAction,
                                                suspendAction: suspendAction,
                                                 resumeAction: resumeAction)
                        }} label: {
                            TransactionRowView(transaction: transaction)
                        }
                    }
//                    .onDelete(perform: removeItems)     // delete this row from the list
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadAllAction()
                }.id(viewId)
                .listStyle(myListStyle.style).anyView
                .onAppear {
                    if showUpDown {
                        upAction = { withAnimation { scrollView.scrollTo(0) }}
                        downAction = { withAnimation { scrollView.scrollTo(transactions.count - 1) }}
                        downAction()
                    }
                }
                .overlay {
                    if transactions.isEmpty {
                        TransactionsEmptyView(currency: currency)
                    }
                }
            }
            .navigationBarItems(trailing: HStack {
                EmptyView()
                if showUpDown {
                    ArrowUpButton(action: upAction)
                    ArrowDownButton(action: downAction)
                }
            })
        }
    }
}
//struct TransactionsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TransactionsView()
//    }
//}
