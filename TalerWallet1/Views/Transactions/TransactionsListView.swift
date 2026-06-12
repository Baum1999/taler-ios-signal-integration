/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import os.log
import SymLog

#if DEBUG
fileprivate let showUpDown = 8      // show up+down buttons in the menubar if list has many lines
#else
fileprivate let showUpDown = 25     // show up+down buttons in the menubar if list has many lines
#endif
struct TransactionsListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    let balance: Balance                            // this is the currency to be used
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    let navTitle: String?

    @Binding var transactions: [TalerTransaction]

    let reloadAllAction: (_ stack: CallStack) async -> ()

    let logger = Logger(subsystem: "net.taler.gnu", category: "TransactionsList")
    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @State private var viewId = UUID()
    @StateObject private var cash: OIMcash
    @Namespace var namespace

    init(stack: CallStack,
         scope: ScopeInfo,
         balance: Balance,
         selectedBalance: Binding<Balance?>,
         navTitle: String?,
         oimEuro: Bool,
         transactions: Binding<[TalerTransaction]>,
         reloadAllAction: @escaping (_ stack: CallStack) async -> ()
    ) {
        // SwiftUI ensures that the initialization uses the
        // closure only once during the lifetime of the view, so
        // later changes to the currency have no effect.
        self.stack = stack
        self.scope = scope
        self.balance = balance
        self.navTitle = navTitle
        self._transactions = transactions
        self.reloadAllAction = reloadAllAction
        self._selectedBalance = selectedBalance
        let oimCurrency = oimCurrency(balance.scopeInfo, oimEuro: oimEuro)
        let oimCash = OIMcash(oimCurrency)
        self._cash = StateObject(wrappedValue: { oimCash }())
    }
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if transactions.isEmpty {
            TransactionsEmptyView(stack: stack.push(), currency: scope.currency)
                .refreshable {
                    controller.hapticNotification(.success)
                    symLog.log("refreshing")
                    await reloadAllAction(stack.push())
                }
        } else {
//            Group {
                ScrollViewReader { scrollProxy in
                    List {
                        let header = scope.url?.trimURL ?? scope.currency
                        TransactionsArraySection(symLog: symLog,
                                                 logger: logger,
                                                  stack: stack.push(),
                                                 header: header,
                                                  scope: scope,
                                           transactions: $transactions,
                                        reloadAllAction: reloadAllAction)
                    }
                    .id(viewId)
                    .listStyle(myListStyle.style).anyView
                    .refreshable {
                        controller.hapticNotification(.success)
                        symLog.log("refreshing")
                        await reloadAllAction(stack.push())
                    }
#if false // SCROLLBUTTONS
                    .if(count > showUpDown) { view in
                        view.navigationBarItems(trailing: HStack {
                            ArrowUpButton {
//                                print("up")
                                withAnimation { scrollProxy.scrollTo(0) }
                            }
                            ArrowDownButton {
//                                print("down")
                                withAnimation { scrollProxy.scrollTo(transactions.count - 1) }
                            }
                        })
                    }
#endif
                } // ScrollViewReader
//              .navigationTitle("EURO")           // Fake EUR instead of the real Currency
//              .navigationTitle("CHF")            // Fake CHF instead of the real Currency
                .navigationTitle(navTitle ?? scope.currency)
                .accessibilityHint(String(localized: "Transaction list", comment: "a11y"))
                .task {
                    symLog.log("❗️.task List❗️")
                    await reloadAllAction(stack.push())
                }
                .onAppear {
                    DebugViewC.shared.setViewID(VIEW_TRANSACTIONLIST, stack: stack.push())
                    print("🚩,32TransactionsListView.onAppear() set selectedBalance to", balance.scopeInfo.currency)
                    selectedBalance = balance           // set this balance (fix) for send/request/deposit/withdraw
                }
//            }
#if OIM
            .overlay { if #available(iOS 16.4, *) {
                if controller.oimModeActive {
                    OIMtransactions(stack: stack.push(),
                                  balance: balance,
                                     cash: cash,
                                  history: transactions)
                    .environmentObject(NamespaceWrapper(namespace))         // keep OIMviews apart
                }
            } }
#endif
        } // not empty
    } // body
}
// MARK: -
// used by TransactionsListView, and by BalancesSectionView to show the last 3 transactions
struct TransactionsArraySection: View {
    let symLog: SymLogV?
    let logger: Logger?
    let stack: CallStack
    let header: String?
    let scope: ScopeInfo
    @Binding var transactions: [TalerTransaction]
    let reloadAllAction: (_ stack: CallStack) async -> ()

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("debugViews") var debugViews: Bool = false

    @State private var talerTX: TalerTransaction = TalerTransaction(dummyCurrency: DEMOCURRENCY)

    @State private var padd = 0

    @ViewBuilder
    func headerView(_ header: String) -> some View {
        Text(header)
            .talerFont(.title3)
            .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let deleteAction = model.deleteTransaction

        Section {
            ForEach(transactions, id: \.self) { transaction in
                let destination = TransactionSummaryList(stack: stack.push(),
                                                 transactionId: transaction.id,
                                                       talerTX: $talerTX,
                                                      navTitle: nil,
                                                       hasDone: false,
                                                      showDone: nil,
                                                           url: nil,
                                                   withActions: true)
                let row = NavigationLink { destination } label: {
                    TransactionRowView(logger: logger, scope: scope, transaction: transaction)
                        .padding(.leading, ICONLEADING)
                        .padding(.trailing, CGFloat(padd))
                }.id(transaction.id)
                if transaction.isDeleteable {
                    row.swipeActions(edge: .trailing) {
                            Button {
                                symLog?.log("deleteAction")
                                Task { // runs on MainActor
                                    let _ = try? await deleteAction(transaction.id, false)
                                    await reloadAllAction(stack.push())
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(WalletColors().negative)
                        }
                } else {
                    row
                }
            }
        } header: {
#if TALER_NIGHTLY
            if developerMode && debugViews {
                HStack {
                    Button("<<") { padd += 10 }
                    Spacer()
                    Button("<") { padd += 1 }
                    Spacer()
                    Button("\(padd)") { padd = 0 }
                    Spacer()
                    Button(">") { padd -= 1 }
                    Spacer()
                    Button(">>") { padd -= 10 }
                }.font(.body)
            } else {
                if let header {
                    headerView(header)
                }
            }
#else
            if let header {
                headerView(header)
            }
#endif
        }
    }
}
