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
    @Binding var summary: String

    @EnvironmentObject private var model: WalletModel

    @State private var isShowingDetailView = false
    @State private var buttonSelected: Int? = nil

    @State private var transactions: [Transaction] = []
    @State private var completedTransactions: [Transaction] = []
    @State private var pendingTransactions: [Transaction] = []
    @State private var uncompletedTransactions: [Transaction] = []

//    func dummyTransaction (_ transactionId: String) async throws {}
    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    func computePending(currency: String) -> (Amount, Amount) {
        var incoming = Amount(currency: currency, value: 0)
        var outgoing = Amount(currency: currency, value: 0)
        for transaction in pendingTransactions {
            let effective = transaction.common.amountEffective
            if currency == effective.currencyStr {
                do {
                    if transaction.common.incoming() {
                        incoming = try incoming + effective
                    } else {
                        outgoing = try outgoing + effective
                    }
                } catch {
                    // TODO: log error
                    symLog.log(error.localizedDescription)
                }
            }
        }
        return (incoming, outgoing)
    }


    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = balance.available.currencyStr
        let reloadCompleted = {
            transactions = await model.fetchTransactionsT(currency: currency)
            completedTransactions = WalletModel.completedTransactions(transactions)
        }
        let reloadPending = {
            transactions = await model.fetchTransactionsT(currency: currency)
            pendingTransactions = WalletModel.pendingTransactions(transactions)
        }
        let reloadUncompleted = {
            transactions = await model.fetchTransactionsT(currency: currency)
            uncompletedTransactions = WalletModel.uncompletedTransactions(transactions)
        }
        let deleteAction = model.deleteTransactionT // dummyTransaction
        let abortAction = model.abortTransactionT

        Section {
//            if "KUDOS" == currency && !balance.available.isZero {
//                Text("You can spend these KUDOS in the [Demo Shop](https://shop.demo.taler.net), or send coins to another wallet.")
//                    .multilineTextAlignment(.leading)
//            }
            HStack(spacing: 0) {
                NavigationLink(destination: LazyView {
                    SendAmount(amountAvailable: balance.available,
                               centsToTransfer: $centsToTransfer,
                                       summary: $summary)
                  }, tag: 1, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                NavigationLink(destination: LazyView {
                    RequestPayment(scopeInfo: balance.scopeInfo,
                             centsToTransfer: $centsToTransfer,
                                     summary: $summary)
                  }, tag: 2, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                NavigationLink(destination: LazyView {
                    TransactionsListView(navTitle: String(localized: "Transactions"), currency: currency,
                                     transactions: completedTransactions,
                                  reloadAllAction: reloadCompleted,
                                  reloadOneAction: reloadOneAction,
                                     deleteAction: deleteAction,
                                      abortAction: abortAction)
                  }, tag: 3, selection: $buttonSelected
                ) { EmptyView() }.frame(width: 0).opacity(0).hidden()

                BalanceRowView(amount: balance.available, sendAction: {
//print("button: Send \(currency)")
                        buttonSelected = 1      // will trigger SendAmount NavigationLink
                    }, recvAction: {
//print("button: Request Payment: \(currency)")
                        buttonSelected = 2      // will trigger RequestPayment NavigationLink
                    }, rowAction: {
//print("button: Transactions: \(currency)")
                        buttonSelected = 3      // will trigger TransactionList NavigationLink
                    })
            }
            let hasPending = pendingTransactions.count > 0
            if hasPending {
                let (pendingIncoming, pendingOutgoing) = computePending(currency: currency)

                NavigationLink {
//let _ = print("button: Pending Transactions: \(currency)")
                    LazyView {
                        TransactionsListView(navTitle: String(localized: "Pending"), currency: currency,
                                         transactions: pendingTransactions,
                                      reloadAllAction: reloadPending,
                                      reloadOneAction: reloadOneAction,
                                         deleteAction: deleteAction,
                                          abortAction: abortAction)
                    }
                } label: {
                    VStack(spacing: 6) {
                        var rows = 0
                        if !pendingIncoming.isZero {
                            PendingRowView(amount: pendingIncoming, incoming: true)
                            let _ = (rows+=1)
                        }
                        if !pendingOutgoing.isZero {
                            PendingRowView(amount: pendingOutgoing, incoming: false)
                            let _ = (rows+=1)
                        }
                        if rows == 0 {
                            Text("Some pending transactions")
                        }
                    }
                }
            }
            let hasUncompleted = uncompletedTransactions.count > 0
            if hasUncompleted {
                NavigationLink {
//let _ = print("button: Uncompleted Transactions: \(currency)")
                    LazyView {
                        TransactionsListView(navTitle: String(localized: "Uncompleted"), currency: currency,
                                             transactions: uncompletedTransactions,
                                          reloadAllAction: reloadUncompleted,
                                          reloadOneAction: reloadOneAction,
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
            let response = await model.fetchTransactionsT(currency: currency)
            transactions = response
            pendingTransactions = WalletModel.pendingTransactions(response)
            uncompletedTransactions = WalletModel.uncompletedTransactions(response)
        }
    } // body
}
// MARK: -
#if DEBUG
fileprivate struct BindingViewContainer : View {
    @State var centsToTransfer: UInt64 = 333
    @State private var summary: String = "bla-bla"

    var body: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, exchangeBaseUrl: DEMOEXCHANGE, currency: LONGCURRENCY)
        let balance = Balance(available: try! Amount(fromString: LONGCURRENCY + ":0.1"),
                              scopeInfo: scopeInfo,
                      requiresUserInput: false,
                 hasPendingTransactions: true)
        List {
            BalancesSectionView(balance: balance,
                        centsToTransfer: $centsToTransfer,
                                summary: $summary)
        }
    }
}

struct BalancesSectionView_Previews: PreviewProvider {
    static var previews: some View {
        BindingViewContainer()
    }
}
#endif
