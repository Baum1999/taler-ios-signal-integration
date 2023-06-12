/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct TransactionsListView: View {
    private let symLog = SymLogV()
    @AppStorage("listStyle") var myListStyle = MyListStyle.automatic
    let navTitle: String

    let currency: String
    let transactions: [Transaction]
    var reloadAction: () async -> ()
    let deleteAction: (_ transactionId: String) async throws -> ()
    let abortAction: (_ transactionId: String) async throws -> ()

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let count = transactions.count
//        let title = AttributedString(localized: "^[\(count) Ticket](inflect: true)")
        let title: String = "\(count) \(navTitle)"
        Content(symLog: symLog, currency: currency, transactions: transactions, myListStyle: $myListStyle,
                reloadAction: reloadAction, deleteAction: deleteAction, abortAction: abortAction)
            .navigationTitle(title)
            .onAppear {
                DebugViewC.shared.setViewID(VIEW_TRANSACTIONLIST)
            }
            .task {
                symLog.log(".task ")
                await reloadAction()
            }
    }
}
// MARK: -
extension TransactionsListView {
    struct Content: View {
        let symLog: SymLogV?
        let currency: String
        let transactions: [Transaction]
        @Binding var myListStyle: MyListStyle
        let reloadAction: () async -> ()
        let deleteAction: (_ transactionId: String) async throws -> ()
        let abortAction: (_ transactionId: String) async throws -> ()

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

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif

            ScrollViewReader { scrollView in
                List {
                    ForEach(Array(zip(transactions.indices, transactions)), id: \.1) { index, transaction in
//                        let common = transaction.common
                        NavigationLink { LazyView {        // whole row like in a tableView
                            // pending may not be deleted, but only aborted
                            TransactionDetailView(transaction: transaction,
                                                 deleteAction: deleteAction,
                                                  abortAction: abortAction)
                        }} label: {
                            TransactionRowView(transaction: transaction)
                        }
                    }
//                    .onDelete(perform: removeItems)     // delete this row from the list
                }
                .refreshable {
                    await reloadAction()
                }
                .listStyle(myListStyle.style)
                .anyView
                .onAppear {
                    upAction = { withAnimation { scrollView.scrollTo(0) }}
                    downAction = { withAnimation { scrollView.scrollTo(transactions.count - 1) }}
                    downAction()
                }
                .overlay {
                    if transactions.isEmpty {
                        TransactionsEmptyView(currency: currency)
                            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
                    }
                }
            }
            .navigationBarItems(trailing: HStack {
                ArrowUpButton(action: upAction)
                ArrowDownButton(action: downAction)
            })
            .navigationBarTitleDisplayMode(.large)      // .inline
        }
    }
}
//struct TransactionsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TransactionsView()
//    }
//}
