/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows a currency section
///     Currency Name
/// [Send Coins]  [Receive Coins]     Balance
///      tapping on Balance leads to completed Transactions (.done)
/// optional:   Pending Incoming
/// optional:   Pending Outgoing
/// optional:   Suspended / Aborting / Aborted / Expired

struct BalancesSectionView: View {
    private let symLog = SymLogV()
    var balance:Balance
    @Binding var centsToTransfer: UInt64
    @ObservedObject var model: TransactionsModel

    @State private var isShowingDetailView = false
    @State private var buttonSelected: Int? = nil
    @State private var completedTransactions: [Transaction] = []
    @State private var pendingTransactions: [Transaction] = []
    @State private var uncompletedTransactions: [Transaction] = []

    var body: some View {
        let currency = balance.available.currencyStr
        let reloadCompleted = {
            await model.fetchTransactions(currency: currency)
            completedTransactions = TransactionsModel.completedTransactions(model.transactions)
        }
        let reloadPending = {
            await model.fetchTransactions(currency: currency)
            pendingTransactions = TransactionsModel.pendingTransactions(model.transactions)
        }
        let reloadUncompleted = {
            await model.fetchTransactions(currency: currency)
            uncompletedTransactions = TransactionsModel.uncompletedTransactions(model.transactions)
        }
        let deleteAction = model.deleteTransaction
        let abortAction = model.abortTransaction


        Section {
            if "KUDOS" == currency && !balance.available.isZero {
                Text("You can spend these KUDOS in the [Demo Shop](https://shop.demo.taler.net), or send coins to another wallet.")
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 0) {
                NavigationLink(destination: LazyView {
                    SendAmount(amountAvailable: balance.available)
                  }, tag: 1, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                NavigationLink(destination: LazyView {
                    RequestPayment(model: Peer2peerModel.model(),
                               scopeInfo: balance.scopeInfo,
                         centsToTransfer: $centsToTransfer)
                        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
                  }, tag: 2, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                NavigationLink(destination: LazyView {
                    TransactionsListView(navTitle: String(localized: "Transactions"), currency: currency,
                                     transactions: completedTransactions,
                                     reloadAction: reloadCompleted,
                                     deleteAction: deleteAction,
                                      abortAction: abortAction)
                  }, tag: 3, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                BalanceRowView(amount: balance.available, sendAction: {
print("button: Send Coins: \(currency)")
                        buttonSelected = 1      // will trigger SendAmount NavigationLink
                    }, recvAction: {
print("button: Request Payment: \(currency)")
                        buttonSelected = 2      // will trigger RequestPayment NavigationLink
                    }, rowAction: {
print("button: Transactions: \(currency)")
                        buttonSelected = 3      // will trigger TransactionList NavigationLink
                    })
            }
            let hasPending = pendingTransactions.count > 0
            if hasPending {
                let hasPendingIn = !balance.pendingIncoming.isZero
                let hasPendingOut = !balance.pendingOutgoing.isZero
                NavigationLink {
let _ = print("button: Pending Transactions: \(currency)")
                    LazyView {
                        TransactionsListView(navTitle: String(localized: "Pending"), currency: currency,
                                         transactions: pendingTransactions,
                                         reloadAction: reloadPending,
                                         deleteAction: deleteAction,
                                          abortAction: abortAction)
                    }
                } label: {
                    VStack(spacing: 6) {
                        if hasPendingIn {
                            PendingRowView(amount: balance.pendingIncoming, incoming: true)
                        }
                        if hasPendingOut {
                            PendingRowView(amount: balance.pendingOutgoing, incoming: false)
                        }
                    }
                }
            }
            let hasUncompleted = uncompletedTransactions.count > 0
            if hasUncompleted {
                NavigationLink {
let _ = print("button: Uncompleted Transactions: \(currency)")
                    LazyView {
                        TransactionsListView(navTitle: String(localized: "Uncompleted"), currency: currency,
                                             transactions: uncompletedTransactions,
                                             reloadAction: reloadUncompleted,
                                             deleteAction: deleteAction,
                                             abortAction: abortAction)
                    }
                } label: {
                    UncompletedRowView(uncompletedTransactions: uncompletedTransactions)
                }

            }
        } header: {
            Text(currency)
                .font(.title)
        } .task {
            await model.fetchTransactions(currency: currency)
            pendingTransactions = TransactionsModel.pendingTransactions(model.transactions)
            uncompletedTransactions = TransactionsModel.uncompletedTransactions(model.transactions)
        }
    } // body
}
// MARK: -
#if DEBUG
fileprivate struct BindingViewContainer : View {
    @State var centsToTransfer: UInt64 = 333
    let model = TransactionsModel.model(currency: LONGCURRENCY)

    var body: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
        let balance = Balance(available: try! Amount(fromString: LONGCURRENCY + ":0.1"),
                        pendingIncoming: try! Amount(fromString: LONGCURRENCY + ":4.8"),
                        pendingOutgoing: try! Amount(fromString: LONGCURRENCY + ":3.25"),
                 hasPendingTransactions: true,
                      requiresUserInput: false,
                              scopeInfo: scopeInfo)
        List {
            BalancesSectionView(balance: balance, centsToTransfer: $centsToTransfer, model: model)
        }
    }
}

struct BalancesSectionView_Previews: PreviewProvider {
    static var previews: some View {
        BindingViewContainer()
    }
}
#endif
