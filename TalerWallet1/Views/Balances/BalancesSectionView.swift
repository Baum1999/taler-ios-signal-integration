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

struct BalancesSectionView {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance                            // this is the currency to be used
    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false
//    @AppStorage("moreContrast") var moreContrast: Bool = false

    @State private var isShowingDetailView = false
    @State private var transactions: [Transaction] = []
    @State private var completedTransactions: [Transaction] = []
    @State private var pendingTransactions: [Transaction] = []
    @State private var incompleteTransactions: [Transaction] = []

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    @State private var sectionID = UUID()
    @State private var shownSectionID = UUID()  // guaranteed to be different the first time

    func reloadCompleted(_ stack: CallStack) async -> () {
        let currency = balance.scopeInfo.currency
        transactions = await model.transactionsT(stack.push(), currency: currency)
        completedTransactions = WalletModel.completedTransactions(transactions)
    }

    func reloadPending(_ stack: CallStack) async -> () {
        let currency = balance.scopeInfo.currency
        transactions = await model.transactionsT(stack.push(), currency: currency)
        pendingTransactions = WalletModel.pendingTransactions(transactions)
    }

    func reloadIncomplete(_ stack: CallStack) async -> () {
        let currency = balance.scopeInfo.currency
        transactions = await model.transactionsT(stack.push(), currency: currency)
        incompleteTransactions = WalletModel.incompleteTransactions(transactions)
    }
}

extension BalancesSectionView: View {
    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currency = balance.scopeInfo.currency
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)

        Section {
            if "KUDOS" == currency && !balance.available.isZero {
                Text(iconOnly ? "Visit the [Demo Shop](https://shop.demo.taler.net)" :
                        "You can spend these KUDOS in the [Demo Shop](https://shop.demo.taler.net), or send them to another wallet.")
                    .accessibilityFont(.body)
                    .multilineTextAlignment(.leading)
            }
            BalancesNavigationLinksView(symLog: symLog,
                                         stack: stack.push(),
                                       balance: balance,
                              amountToTransfer: $amountToTransfer,      // does still have the wrong currency
                                       summary: $summary,
                         completedTransactions: $completedTransactions,
                               reloadAllAction: reloadCompleted,
                               reloadOneAction: reloadOneAction)
            if pendingTransactions.count > 0 {
                BalancesPendingRowView(symLog: symLog,
                                        stack: stack.push(),
                                     currency: currency,
                          pendingTransactions: $pendingTransactions,
                                reloadPending: reloadPending,
                              reloadOneAction: reloadOneAction)
            }
            if incompleteTransactions.count > 0 {
                NavigationLink {
//let _ = print("button: Incomplete Transactions: \(currency)")
                    LazyView {
                        TransactionsListView(stack: stack.push(),
                                          navTitle: String(localized: "Incomplete", comment: "ViewTitle of TransactionList"),
                                          currency: currency,
                                      transactions: incompleteTransactions,
                                        showUpDown: false,
                                   reloadAllAction: reloadIncomplete,
                                   reloadOneAction: reloadOneAction)
                    }
                } label: {
                    IncompleteRowV(incompleteTransactions: $incompleteTransactions)
                }

            }
        } header: {
            BarGraphHeader(stack: stack.push(), currency: currency)
        }.id(sectionID)
        .task {
//            if shownSectionID != sectionID {
                symLog.log(".task for BalancesSectionView - reload Transactions")
                let response = await model.transactionsT(stack.push(".task - reload Transactions"), currency: currency)
                transactions = response
                pendingTransactions = WalletModel.pendingTransactions(response)
                incompleteTransactions = WalletModel.incompleteTransactions(response)
                completedTransactions = WalletModel.completedTransactions(response)
                shownSectionID = sectionID
//            } else {
//                symLog.log("task for BalancesSectionView \(sectionID) ❗️ skip reloading Transactions")
//            }
        }
        let transactionCount = completedTransactions.count
        /// if there is only one currency, then show recent transactions
        if sectionCount == 1 && transactionCount > 0 {
            Section {
                let slice = completedTransactions.prefix(3)         // already sorted
                let threeTransactions = Array(slice)
                TransactionsArraySliceV(symLog: symLog,
                                         stack: stack.push(),
                                      currency: currency,
                                  transactions: threeTransactions,
                               reloadOneAction: reloadOneAction)
            } header: {
                if !iconOnly {
                    Text("Recent transactions")
                        .accessibilityFont(.callout)
//                        .foregroundColor(moreContrast ? .primary : .secondary)
                }
            }
        } // recent transactions
    } // body
} // BalancesSectionView

fileprivate struct BalancesPendingRowView: View {
    let symLog: SymLogV?
    let stack: CallStack
    let currency: String // = currencyInfo.scope.currency
    @Binding var pendingTransactions: [Transaction]
    let reloadPending: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String) async throws -> Transaction)

    func computePending(currency: String) -> (Amount, Amount) {
        var incoming = Amount(currency: currency, cent: 0)
        var outgoing = Amount(currency: currency, cent: 0)
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
                    symLog?.log(error.localizedDescription)
                }
            }
        }
        return (incoming, outgoing)
    }

    var body: some View {
        let (pendingIncoming, pendingOutgoing) = computePending(currency: currency)

        NavigationLink {
            //let _ = print("button: Pending Transactions: \(currency)")
            LazyView {
                TransactionsListView(stack: stack.push(),
                                  navTitle: String(localized: "Pending", comment: "ViewTitle of TransactionList"),
                                  currency: currency,
                              transactions: pendingTransactions,
                                showUpDown: false,
                           reloadAllAction: reloadPending,
                           reloadOneAction: reloadOneAction)
            }
        } label: {
            let needsKYC = true
            let shouldConfirm = false
            let needsKYCStr = String(localized: ". Needs K Y C", comment: "VoiceOver")
            let needsConfStr = String(localized: ". Needs bank confirmation", comment: "VoiceOver")
            VStack(spacing: 6) {
                var rows = 0
                if !pendingIncoming.isZero {
                    PendingRowView(amount: pendingIncoming, incoming: true, shouldConfirm: false, needsKYC: false)     // TODO: !!!
                    let _ = (rows+=1)
                }
                if !pendingOutgoing.isZero {
                    PendingRowView(amount: pendingOutgoing, incoming: false, shouldConfirm: false, needsKYC: false)
                    let _ = (rows+=1)
                }
                if rows == 0 {
                    Text("Some pending transactions")
                        .accessibilityFont(.body)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(needsKYC && shouldConfirm ? needsKYCStr + needsConfStr :
                                                 needsKYC ? needsKYCStr :
                                            shouldConfirm ? needsConfStr
                                                          : EMPTYSTRING)
            .accessibilityHint("Will go to Pending transactions.")

        }

    } // body
} // BalancesPendingRowView

fileprivate struct BalancesNavigationLinksView: View {
    let symLog: SymLogV?
    let stack: CallStack
    let balance: Balance
//    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var completedTransactions: [Transaction]
    let reloadAllAction: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String) async throws -> Transaction)
//    @EnvironmentObject private var model: WalletModel

    @State private var buttonSelected: Int? = nil

    func selectAndUpdate(_ button: Int) {
        let currency = balance.scopeInfo.currency
        amountToTransfer.setCurrency(currency)
        symLog?.log("balance.scopeInfo.currency: \(currency)")

        buttonSelected = button      // will trigger NavigationLink
        // while navigation animation runs, contact Exchange to update Fees
//        Task { // runs on MainActor
//            do {
//                try await model.updateExchange(scopeInfo: balance.scopeInfo)
//            } catch {    // TODO: error handling - couldn't updateExchange
//                symLog.log("error: \(error)")
//            }
//        }
    }

    var body: some View {
        let currency = balance.scopeInfo.currency
        HStack(spacing: 0) {
            NavigationLink(destination: LazyView {
                SendAmount(stack: stack.push(),
                 amountAvailable: balance.available,
                amountToTransfer: $amountToTransfer,        // with correct currency
                         summary: $summary)
            }, tag: 1, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0).hidden()           // SendAmount

            NavigationLink(destination: LazyView {
                RequestPayment(stack: stack.push(),
                    amountToTransfer: $amountToTransfer,    // with correct currency
                             summary: $summary)
            }, tag: 2, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0).hidden()           // RequestPayment

            NavigationLink(destination: LazyView {
                TransactionsListView(stack: stack.push(),
                                  navTitle: String(localized: "Transactions", comment: "ViewTitle of TransactionList"),
                                  currency: currency,
                              transactions: completedTransactions,
                                showUpDown: true,
                           reloadAllAction: reloadAllAction,
                           reloadOneAction: reloadOneAction)
            }, tag: 3, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0).hidden()           // TransactionsListView

            BalanceRowView(amount: balance.available,
                       sendAction: {
                            selectAndUpdate(1)      // trigger SendAmount NavigationLink
                    }, recvAction: {
                            selectAndUpdate(2)      // trigger RequestPayment NavigationLink
                     }, rowAction: {
                            buttonSelected = 3      // trigger TransactionList NavigationLink
                     })
        }
    }
}
// MARK: -
#if false   // model crashes
struct BalancesSectionView_Previews: PreviewProvider {
fileprivate struct BindingViewContainer: View {
    @State var amountToTransfer: UInt64 = 333
    @State private var summary: String = "bla-bla"

    var body: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, url: DEMOEXCHANGE, currency: LONGCURRENCY)
        let balance = Balance(available: Amount(currency: LONGCURRENCY, cent:1),
                              scopeInfo: scopeInfo,
                      requiresUserInput: false,
                 hasPendingTransactions: true)
        BalancesSectionView(balance: balance,
                       sectionCount: 2,
                   amountToTransfer: $amountToTransfer,
                            summary: $summary)
    }
}

    static var previews: some View {
        List {
            BindingViewContainer()
        }
    }
}
#endif
