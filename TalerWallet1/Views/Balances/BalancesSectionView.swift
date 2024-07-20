/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
/// [􁉇Send $currency]  [􁉅Request $currency]
/// optional:   Pending Incoming
/// optional:   Pending Outgoing
/// optional:   [􀰟Spend KUDOS]
/// [􁾭Withdraw $currency]  [􁾩Deposit $currency]
/// optional?:   Suspended / Aborting / Aborted / Expired

struct BalancesSectionView {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance                            // this is the currency to be used
    let sectionCount: Int
    @Binding var amountToTransfer: Amount           // does still have the wrong currency
    @Binding var summary: String
    @Binding var shouldReloadBalances: Int
    let cameraAction: () -> Void

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
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero("UNKNOWN")
    @State private var currencyName: String = "UNKNOWN"
//    @State private var buttonSelected: Int? = nil

    private static func className() -> String {"\(self)"}

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

extension BalancesSectionView: View {
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scopeInfo = balance.scopeInfo
        let currency = scopeInfo.currency
        let _ = symLog.log("BalancesSectionView❗️ \(currencyInfo.scope.currency) used as currencyInfo")

        let balanceDest = LazyView {
            TransactionsListView(stack: stack.push("\(Self.className())()"),
                              navTitle: String(localized: "Transactions", comment: "ViewTitle of TransactionList"),
                             scopeInfo: scopeInfo,
                          transactions: completedTransactions,
                       reloadAllAction: reloadCompleted,
                       reloadOneAction: reloadOneAction)
        }

        Section {
            if scopeInfo.type == .exchange {
                let baseURL = scopeInfo.url?.trimURL() ?? String(localized: "Unknown Payment Provider", comment: "exchange url")
                Text(baseURL)
                    .talerFont(.headline)
//                    .listRowSeparator(.hidden)
            }
            BalanceCellV(stack: stack.push("BalanceCell"),
                  currencyInfo: currencyInfo,
                        amount: balance.available,
//                        sizeCategory: sizeCategory,
//                     rowAction: { buttonSelected = 3 },     // trigger TransactionList NavigationLink
                   balanceDest: balanceDest)
//            .listRowSeparator(.hidden)
//            .border(.red)

            SendRequestV(stack: stack.push(),
                  currencyInfo: currencyInfo,
               amountAvailable: balance.available,
              amountToTransfer: $amountToTransfer,
                       summary: $summary,
                  cameraAction: cameraAction)
//            .listRowSeparator(.hidden)

//            BalancesNavigationLinksV(symLog: symLog,
//                                         stack: stack.push("Section"),
//                                  currencyInfo: currencyInfo,
//                                       balance: balance,
//                              amountToTransfer: $amountToTransfer,      // does still have the wrong currency
//                                       summary: $summary,
//                         completedTransactions: $completedTransactions,
//                               reloadAllAction: reloadCompleted,
//                               reloadOneAction: reloadOneAction,
//                                  cameraAction: cameraAction)

            if pendingTransactions.count > 0 {
                BalancesPendingRowV(//symLog: symLog,
                                     stack: stack.push(),
                              currencyInfo: currencyInfo,
                                   balance: balance,
                       pendingTransactions: $pendingTransactions,
                             reloadPending: reloadPending,
                           reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            }
            let showSpendingButton = DEMOCURRENCY == currency && !balance.available.isZero
            if showSpendingButton {
                if !minimalistic && showSpendingHint {
                    Text("You can spend these \(currencyName) in the Demo shop, or send them to another wallet.")
                        .talerFont(.body)
                        .multilineTextAlignment(.leading)
                        .listRowSeparator(.hidden)
                }
                let title = String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend demo money")
                let action = {
                    showSpendingHint = false
                    UIApplication.shared.open(URL(string:DEMOSHOP)!, options: [:])
                }
                Button(action: action) {
                    HStack {
                        ButtonIconBadge(type: .payment, foreColor: .accentColor, done: false)
                        Spacer()
                        Text(title)
                        Spacer()
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .accessibilityHint(String(localized: "Will go to the demo shop website."))
                .listRowSeparator(.hidden)
            }
            DepositWithdrawV(stack: stack.push(),
                      currencyInfo: currencyInfo,
//                         scopeInfo: balance.scopeInfo,
                   amountAvailable: balance.available,
                  amountToTransfer: $amountToTransfer)   // does still have the wrong currency

        } header: {
            BarGraphHeader(stack: stack.push(), scopeInfo: scopeInfo, currencyName: currencyName,
                           shouldReloadBalances: $shouldReloadBalances)
        }.id(sectionID)
        .listRowSeparator(.hidden)
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
