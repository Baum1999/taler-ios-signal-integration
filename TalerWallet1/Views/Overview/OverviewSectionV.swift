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

struct OverviewSectionV {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance                            // this is the currency to be used
    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var shouldReloadBalances: Int

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var controller: Controller
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var showSpendingHint = true
    @State private var isShowingDetailView = false
    @State private var transactions: [Transaction] = []
    @State private var completedTransactions: [Transaction] = []
    @State private var pendingTransactions: [Transaction] = []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var currencyName: String = UNKNOWN

    func reloadOneAction(_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId, viewHandles: viewHandles)
    }

    @State private var sectionID = UUID()
    @State private var shownSectionID = UUID()  // guaranteed to be different the first time

    func reloadCompleted(_ stack: CallStack) async -> () {
        if let transactions = try? await model.transactionsT(stack.push(), scopeInfo: balance.scopeInfo, includeRefreshes: developerMode) {
            completedTransactions = WalletModel.completedTransactions(transactions)
        }
    }

    func reloadPending(_ stack: CallStack) async -> () {
        if let transactions = try? await model.transactionsT(stack.push(), scopeInfo: balance.scopeInfo, includeRefreshes: developerMode) {
            pendingTransactions = WalletModel.pendingTransactions(transactions)
        }
    }
}

extension OverviewSectionV: View {
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scopeInfo = balance.scopeInfo
        let currency = scopeInfo.currency
//        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
//        let currencyName = currencyInfo.scope.currency

        Section {
            if scopeInfo.type == .exchange {
                let baseURL = scopeInfo.url?.trimURL() ?? String(localized: "Unknown Payment Provider", comment: "exchange url")
                Text(baseURL)
                    .talerFont(.headline)
                    .listRowSeparator(.hidden)
            }
            CurrenciesNavigationLinksV(symLog: symLog,
                                         stack: stack.push(),
                                  currencyInfo: $currencyInfo,
                                       balance: balance,
                              amountToTransfer: $amountToTransfer,      // does still have the wrong currency
                                       summary: $summary,
                         completedTransactions: $completedTransactions,
                               reloadAllAction: reloadCompleted,
                               reloadOneAction: reloadOneAction)
            if pendingTransactions.count > 0 {
                BalancesPendingRowV(//symLog: symLog,
                                    stack: stack.push(),
                             currencyInfo: $currencyInfo,
                                  balance: balance,
                      pendingTransactions: $pendingTransactions,
                            reloadPending: reloadPending,
                          reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            }
        } header: {
            BarGraphHeader(stack: stack.push(), scopeInfo: scopeInfo, currencyName: currencyName,
                           shouldReloadBalances: $shouldReloadBalances)
        }.id(sectionID)
        .task(id: controller.currencyTicker) {
            currencyInfo = controller.info(for: currency, controller.currencyTicker)
            currencyName = currencyInfo.scope.currency
        }
        .task(id: shouldReloadBalances + 1_000_000) {
//            if shownSectionID != sectionID {
                symLog.log(".task for BalancesSectionView - reload Transactions")
            // TODO: only load the MAXRECENT most recent transactions
            if let response = try? await model.transactionsT(stack.push(".task - reload Transactions"), scopeInfo: scopeInfo, includeRefreshes: developerMode) {
                transactions = response
                pendingTransactions = WalletModel.pendingTransactions(response)
                completedTransactions = WalletModel.completedTransactions(response)
                shownSectionID = sectionID
            }
//            } else {
//                symLog.log("task for BalancesSectionView \(sectionID) ❗️ skip reloading Transactions")
//            }
        }
        let transactionCount = completedTransactions.count
        /// if there is only one currency, then show MAXRECENT recent transactions
        if sectionCount == 1 && transactionCount > 0 {
            Section {
                let slice = completedTransactions.prefix(MAXRECENT)         // already sorted
                let threeTransactions = Array(slice)
                TransactionsArraySliceV(symLog: symLog,
                                         stack: stack.push(),
                                  currencyInfo: $currencyInfo,
                                     scopeInfo: scopeInfo,
                                  transactions: threeTransactions,
                               reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            } header: {
                if !minimalistic {
                    let count = transactionCount > MAXRECENT ? MAXRECENT : transactionCount
                    Text(count > 1 ? "Recent \(count) transactions"
                                   : "Recent transaction")
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                }
            }
        } // recent transactions
    } // body
} // OverviewSectionV
// MARK: -
fileprivate struct CurrenciesNavigationLinksV: View {
    let symLog: SymLogV?
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    let balance: Balance
    
//    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var completedTransactions: [Transaction]
    let reloadAllAction: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)
//    @EnvironmentObject private var model: WalletModel

    @State private var buttonSelected: Int? = nil

    func selectAndUpdate(_ button: Int) {
        let currency = balance.scopeInfo.currency
        amountToTransfer.setCurrency(currency)      // replace wrong currency here
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
        let scopeInfo = balance.scopeInfo
        HStack(spacing: 0) {
            let balanceDest = LazyView {
                TransactionsListView(stack: stack.push(),
                              currencyInfo: $currencyInfo,
                                  navTitle: String(localized: "Transactions", comment: "ViewTitle of TransactionList"),
                                 scopeInfo: scopeInfo,
                              transactions: completedTransactions,
                           reloadAllAction: reloadAllAction,
                           reloadOneAction: reloadOneAction)
            }
            NavigationLink(destination: balanceDest, tag: 3, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()           // TransactionsListView

            OverviewRowV(stack: stack.push(),
                  currencyInfo: $currencyInfo,
                        amount: balance.available,
                    sendAction: {
                        selectAndUpdate(1)      // trigger SendAmount NavigationLink
                 }, recvAction: {
                        selectAndUpdate(2)      // trigger RequestPayment NavigationLink
                  }, rowAction: {
                        buttonSelected = 3      // trigger TransactionList NavigationLink
                }, balanceDest: balanceDest)
        }
    }
}
