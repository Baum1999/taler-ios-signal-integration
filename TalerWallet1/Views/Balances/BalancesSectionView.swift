/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
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
    let balanceIndex: Int
    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var historyTapped: Int?
    @Binding var reloadTransactions: Int

    let logger = Logger(subsystem: "net.taler.gnu", category: "RecentList")
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
    @AppStorage("oimEuro") var oimEuro: Bool = false

    @State private var showSpendingHint = true
    @State private var isShowingDetailView = false
    @State private var completedTransactions: [TalerTransaction] = []
    @State private var recentTransactions: [TalerTransaction] = []
    @State private var pendingTransactions: [TalerTransaction] = []
    @State private var scannedTransactions: [TalerTransaction] = []

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
            withAnimation { recentTransactions = transactions }
        }
    }
    @MainActor
    func loadCompleted(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadCompleted - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .final,
                                               includeRefreshes: developerMode) {
            withAnimation { completedTransactions = transactions }
        }
    }
    @MainActor
    func loadPending(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadPending - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .nonfinalApproved,
                                               includeRefreshes: developerMode) {
            withAnimation { pendingTransactions = transactions }
        }
    }
    @MainActor
    func loadScanned(_ stack: CallStack) async -> () {
        if let transactions = try? await model.getTransactionsV2(stack.push("loadScanned - \(balance.scopeInfo.url?.trimURL)"),
                                                          scope: balance.scopeInfo,
                                                  filterByState: .nonfinalDialog,
                                               includeRefreshes: developerMode) {
            withAnimation { scannedTransactions = transactions }
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
        let balanceDest = TransactionsListView(stack: stack.push("BalanceCellV"),
                                               scope: scopeInfo,
                                             balance: balance,
                                     selectedBalance: $selectedBalance,
                                            navTitle: balance.available.readableDescription,    // TODO: format with currency sign
                                             oimEuro: oimEuro,
                                        transactions: $completedTransactions,
                                     reloadAllAction: loadCompleted)
        let isLegacy = scopeInfo.type == .exchangeLegacyKeys
        Section {
            if scopeInfo.type == .exchange || isLegacy {
                let baseURL = scopeInfo.url?.trimURL ?? String(localized: "Unknown payment service", comment: "exchange url")
                Text(baseURL)
                    .talerFont(.subheadline)
                    .foregroundColor(.secondary)
            //      .listRowSeparator(.hidden)
            }
            BalanceCellV(stack: stack.push("BalanceCell"),
                         scope: balance.scopeInfo,
                        amount: balance.available,
                      isLegacy: isLegacy,
                 historyTapped: $historyTapped,
                  balanceIndex: balanceIndex,
                   balanceDest: balanceDest)
//            .listRowSeparator(.hidden)
//            .border(.red)

            if !pendingTransactions.isEmpty {
                BalancesPendingRowV(//symLog: symLog,
                                     stack: stack.push(),
                                   balance: balance,
                           selectedBalance: $selectedBalance,
                       pendingTransactions: $pendingTransactions,
                             reloadPending: loadPending)
                    .padding(.leading, ICONLEADING)
            }
            if !scannedTransactions.isEmpty {
                BalancesDialogRowV(stack: stack.push(),
                                 balance: balance,
                         selectedBalance: $selectedBalance,
                     scannedTransactions: $scannedTransactions,
                           reloadScanned: loadScanned)
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
            await loadCompleted(stack.push(".task - load completed"))       // TODO: only in TX list view
            await loadPending(stack.push(".task - load pending"))
            await loadScanned(stack.push(".task - load scanned"))
        }
        if sectionCount == 1 {
            // show Discounts & Passes before recents
            DiscountPassesSection(stack: stack.push())
            // if there is only one currency, then show MAXRECENT recent transactions
            let recentCount = recentTransactions.count
            if recentCount > 0 {
                let _ = symLog.log("recent transactions")
                let recentHeader = minimalistic ? nil
                                 : recentCount > 1
                    ? String(localized: "Recent transactions", comment: "section header plural")
                    : String(localized: "Recent transaction", comment: "section header singular")
                TransactionsArraySection(symLog: symLog,
                                         logger: logger,
                                          stack: stack.push(),
                                         header: recentHeader,
                                          scope: scopeInfo,
                                   transactions: $recentTransactions,
                                reloadAllAction: loadRecent)
            } // recent transactions
        } // 1 Section only
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
