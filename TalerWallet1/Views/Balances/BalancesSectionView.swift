/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows a currency section
///     Currency Name
/// "Balance"                   $balance                    // leads to completed Transactions (.done)
/// optional:   Pending Incoming
/// optional:   Pending Outgoing
/// optional?:   Suspended / Aborting / Aborted / Expired
struct BalancesSectionView {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance                            // this is the currency to be used
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    let selectedChestIndex: Int?
    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var historyTapped: Bool
    @Binding var reloadTransactions: Int

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
    @State private var completedTransactions: [TalerTransaction] = []
    @State private var recentTransactions: [TalerTransaction] = []
    @State private var pendingTransactions: [TalerTransaction] = []

    private static func className() -> String {"\(self)"}

    @State private var sectionID = UUID()
    @State private var shownSectionID = UUID()  // guaranteed to be different the first time

    @MainActor
    func loadRecent(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadRecent - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .final,
                                                          limit: MAXRECENT,
                                               includeRefreshes: false) {
//            let recent = WalletModel.completedTransactions(transactions)
//            let slice = recent.prefix(MAXRECENT)         // already sorted
//            withAnimation { recentTransactions = Array(slice) }
            withAnimation { recentTransactions = transactions }
        }
    }
    @MainActor
    func loadCompleted(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadCompleted - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .final,
                                               includeRefreshes: developerMode) {
//            let completed = WalletModel.completedTransactions(transactions)
//            withAnimation { completedTransactions = completed }
            withAnimation { completedTransactions = transactions }
        }
    }
    @MainActor
    func loadPending(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadPending - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .nonfinal,
                                               includeRefreshes: developerMode) {
            withAnimation { pendingTransactions = transactions }
        }
    }
}

extension BalancesSectionView: View {
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scopeInfo = balance.scopeInfo

      Group {
            let balanceDest = TransactionsListView(stack: stack.push("\(Self.className())()"),
                                                   scope: scopeInfo,
                                                 balance: balance,
                                         selectedBalance: $selectedBalance,
                                                navTitle: balance.available.readableDescription,    // TODO: format with currency sign
                                            transactions: $completedTransactions,
                                         reloadAllAction: loadCompleted)
          Section {
            if scopeInfo.type == .exchange {
                let baseURL = scopeInfo.url?.trimURL ?? String(localized: "Unknown payment service", comment: "exchange url")
                Text(baseURL)
                    .talerFont(.subheadline)
                    .foregroundColor(.secondary)
            //      .listRowSeparator(.hidden)
            }
            BalanceCellV(stack: stack.push("BalanceCell"),
                         scope: balance.scopeInfo,
                        amount: balance.available,
                 historyTapped: $historyTapped,
                   balanceDest: balanceDest)
//            .listRowSeparator(.hidden)
//            .border(.red)

            if pendingTransactions.count > 0 {
                BalancesPendingRowV(//symLog: symLog,
                                     stack: stack.push(),
                                   balance: balance,
                           selectedBalance: $selectedBalance,
                        selectedChestIndex: selectedChestIndex,
                       pendingTransactions: $pendingTransactions,
                             reloadPending: loadPending)
                    .padding(.leading, ICONLEADING)
            }
        } header: {
            BarGraphHeader(stack: stack.push(),
                           scope: scopeInfo,
              reloadTransactions: $reloadTransactions)
        }.id(sectionID)
        .listRowSeparator(.hidden)
        .task(id: reloadTransactions + 1_000_000) {
            symLog.log(".task for BalancesSectionView - load recent+completed+pending")
            await loadRecent(stack.push(".task - load recent"))
            await loadCompleted(stack.push(".task - load completed"))
            await loadPending(stack.push(".task - load pending"))
        }
        /// if there is only one currency, then show MAXRECENT recent transactions
        if sectionCount == 1 && recentTransactions.count > 0 {
            Section {
                let _ = symLog.log("recent transactions")
                TransactionsArraySliceV(symLog: symLog,
                                         stack: stack.push(),
                                         scope: scopeInfo,
                                  transactions: $recentTransactions,
                               reloadAllAction: loadRecent)
                    .padding(.leading, ICONLEADING)
            } header: {
                if !minimalistic {
                    let recentHeader = recentTransactions.count > 1
                        ? String(localized: "Recent transactions", comment: "section header plural")
                        : String(localized: "Recent transaction", comment: "section header singular")
                    Text(recentHeader)
                        .talerFont(.title3)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                }
            }
        } // recent transactions
      }
    } // body
} // BalancesSectionView
// MARK: -
#if false   // model crashes
struct BalancesSectionView_Previews: PreviewProvider {
fileprivate struct BindingViewContainer: View {
    @State var amountToTransfer: UInt64 = 333
    @State private var summary: String = "bla-bla"

    var body: some View {
        let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, url: DEMOEXCHANGE, currency: LONGCURRENCY)
        let balance = Balance(scopeInfo: scopeInfo,
                              available: Amount(currency: LONGCURRENCY, cent:1),
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
