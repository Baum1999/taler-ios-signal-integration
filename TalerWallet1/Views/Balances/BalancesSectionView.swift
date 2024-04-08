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

    func reloadOneAction(_ transactionId: String) async throws -> Transaction {
        return try await model.getTransactionByIdT(transactionId)
    }

    @State private var sectionID = UUID()
    @State private var shownSectionID = UUID()  // guaranteed to be different the first time

    func reloadCompleted(_ stack: CallStack) async -> () {
        transactions = await model.transactionsT(stack.push(), scopeInfo: balance.scopeInfo, includeRefreshes: developerMode)
        completedTransactions = WalletModel.completedTransactions(transactions)
    }

    func reloadPending(_ stack: CallStack) async -> () {
        transactions = await model.transactionsT(stack.push(), scopeInfo: balance.scopeInfo, includeRefreshes: developerMode)
        pendingTransactions = WalletModel.pendingTransactions(transactions)
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
        let currencyInfo = controller.info(for: currency)

        Section {
            if scopeInfo.type == .exchange {
                let baseURL = scopeInfo.url?.trimURL() ?? String(localized: "Unknown Payment Provider", comment: "exchange url")
                Text(baseURL)
                    .talerFont(.headline)
                    .listRowSeparator(.hidden)
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
                                      balance: balance,
                          pendingTransactions: $pendingTransactions,
                                reloadPending: reloadPending,
                              reloadOneAction: reloadOneAction)
                    .padding(.leading, ICONLEADING)
            }
            let currencyName = currencyInfo?.scope.currency ?? currency
            let showSpendingButton = DEMOCURRENCY == currency && !balance.available.isZero
            if showSpendingButton {
                if !minimalistic && showSpendingHint {
                    Text("You can spend these \(currencyName) in the Demo shop, or send them to another wallet.")
                        .talerFont(.body)
                        .multilineTextAlignment(.leading)
                        .listRowSeparator(.hidden)
                }
            }
            if showSpendingButton {
                let title = String(localized: "LinkTitle_DEMOSHOP", defaultValue: "Spend test money")
                Button(title) {
                    showSpendingHint = false
                    UIApplication.shared.open(URL(string:DEMOSHOP)!, options: [:])
                }
                .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                .accessibilityHint("Will go to the demo shop website.")
                .listRowSeparator(.hidden)
            }
            DepositWithdrawV(stack: stack.push(),
                         scopeInfo: balance.scopeInfo,
                   amountAvailable: balance.available,
                          currency: currencyName,
                  amountToTransfer: $amountToTransfer)   // does still have the wrong currency
            .listRowSeparator(.hidden)

        } header: {
            BarGraphHeader(stack: stack.push(), scopeInfo: scopeInfo,
                    currencyName: currencyInfo?.scope.currency ?? currency,
            shouldReloadBalances: $shouldReloadBalances)
        }.id(sectionID)
        .task(id: shouldReloadBalances + 1_000_000) {
//            if shownSectionID != sectionID {
                symLog.log(".task for BalancesSectionView - reload Transactions")
            // TODO: only load the MAXRECENT most recent transactions
            let response = await model.transactionsT(stack.push(".task - reload Transactions"), scopeInfo: scopeInfo, includeRefreshes: developerMode)
                transactions = response
                pendingTransactions = WalletModel.pendingTransactions(response)
                completedTransactions = WalletModel.completedTransactions(response)
                shownSectionID = sectionID
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
fileprivate struct BalancesPendingRowView: View {
    let symLog: SymLogV?
    let stack: CallStack
//    let currency: String // = currencyInfo.scope.currency
    let balance: Balance                            // this is the currency to be used
    @Binding var pendingTransactions: [Transaction]
    let reloadPending: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String) async throws -> Transaction)

    var body: some View {
        let pendingIncoming = balance.pendingIncoming
        let pendingOutgoing = balance.pendingOutgoing
        let needsKYCin = balance.flags.contains(.incomingKyc)
        let needsKYCout = balance.flags.contains(.outgoingKyc)
        let shouldConfirm = balance.flags.contains(.incomingConfirmation)

        NavigationLink {
            //let _ = print("button: Pending Transactions: \(currency)")
            LazyView {
                TransactionsListView(stack: stack.push(),
                                  navTitle: String(localized: "Pending", comment: "ViewTitle of TransactionList"),
                                 scopeInfo: balance.scopeInfo,
                              transactions: pendingTransactions,
                                showUpDown: false,
                           reloadAllAction: reloadPending,
                           reloadOneAction: reloadOneAction)
            }
        } label: {
            let needsKYC =  needsKYCin || needsKYCout
            let needsKYCStr = String(localized: ". Needs K Y C", comment: "VoiceOver")
            let needsConfStr = String(localized: ". Needs bank confirmation", comment: "VoiceOver")
            VStack(spacing: 6) {
                let hasIncoming = !pendingIncoming.isZero
                if hasIncoming {
                    PendingRowView(amount: pendingIncoming, incoming: true,
                            shouldConfirm: shouldConfirm, needsKYC: needsKYCin)
                }
                let hasOutgoing = !pendingOutgoing.isZero
                if hasOutgoing {
                    PendingRowView(amount: pendingOutgoing, incoming: false,
                            shouldConfirm: false, needsKYC: needsKYCout)
                }
                if !hasIncoming && !hasOutgoing {           // should never happen
                    Text("Some pending transactions")
                        .talerFont(.body)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(needsKYC && shouldConfirm ? needsKYCStr + needsConfStr :
                                                 needsKYC ? needsKYCStr :
                                            shouldConfirm ? needsConfStr
                                                          : EMPTYSTRING)
            .accessibilityHint("Will go to Pending transactions.")
        } // NavLinkLabel
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
            NavigationLink(destination: LazyView {
                SendAmount(stack: stack.push(),
                 amountAvailable: balance.available,
                amountToTransfer: $amountToTransfer,        // with correct currency
                         summary: $summary,
                       scopeInfo: balance.scopeInfo)
            }, tag: 1, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0).hidden()           // SendAmount

            NavigationLink(destination: LazyView {
                RequestPayment(stack: stack.push(),
                    amountToTransfer: $amountToTransfer,    // with correct currency
                             summary: $summary,
                           scopeInfo: balance.scopeInfo)
            }, tag: 2, selection: $buttonSelected
            ) { EmptyView() }.frame(width: 0).opacity(0).hidden()           // RequestPayment

            let balanceDest = LazyView {
                TransactionsListView(stack: stack.push(),
                                  navTitle: String(localized: "Transactions", comment: "ViewTitle of TransactionList"),
                                 scopeInfo: scopeInfo,
                              transactions: completedTransactions,
                                showUpDown: true,
                           reloadAllAction: reloadAllAction,
                           reloadOneAction: reloadOneAction)
            }
            NavigationLink(destination: balanceDest, tag: 3, selection: $buttonSelected)
                { EmptyView() }.frame(width: 0).opacity(0).hidden()           // TransactionsListView

            BalanceRowView(stack: stack.push(),
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
