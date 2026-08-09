/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Called from DepositSelectV -> BankSectionView
struct DepositAmountAction: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    // when Action is tapped while in currency TransactionList…
    let selectedBalance: Balance?   // …then use THIS balance, otherwise show picker
    @Binding var amountLastUsed: Amount
    let paytoUri: String?
    let label: String?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // GetMaxPeerPushAmount
    @State private var depositStarted = false
    @State private var txId: String? = nil
    @State private var talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY)

    @MainActor
    private func viewDidLoad() async {
        let balances = controller.balances
        if let selectedBalance {
            let disableDeposits = selectedBalance.disableDirectDeposits ?? false
            if disableDeposits {
                // find another balance
                balance = Balance.firstwithDeposit(balances)
            } else {
                balance = selectedBalance
            }
        } else {
            balance = Balance.firstwithDeposit(balances)
        }
        if let balance {
            balanceIndex = balances.firstIndex(of: balance) ?? 0
        } else {
            balanceIndex = 0
            balance = balances.isEmpty ? nil : balances[0]
        }
    }

    @MainActor
    private func newBalance() async {
        // runs whenever the user changes the exchange via ScopePicker, or on new currencyInfo
        symLog.log("❗️ task \(balanceIndex)")
        if let balance {
            let scope = balance.scopeInfo
            amountToTransfer.setCurrency(scope.currency)
            currencyInfo = controller.info(for: scope, controller.currencyTicker)
            do {
                amountAvailable = try await model.getMaxDepositAmount(scope)
            } catch {
                // TODO: Error
                amountAvailable = balance.available
            }
        }
    }

    @MainActor
    private func startDeposit(_ scope: ScopeInfo) {
        if let paytoUri {
            depositStarted = true    // don't run twice
            Task {
                symLog.log("Deposit")
                if let result = try? await model.createDepositGroup(paytoUri,
                                                                    scope: scope,
                                                                    amount: amountToTransfer) {
                    symLog.log(result.transactionId)
                    txId = result.transactionId
                } else {
                    depositStarted = false
                }
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
        if let txId {
            TransactionSummaryList(stack: stack.push(),
                           transactionId: txId,
                                 talerTX: $talerTX,
                                navTitle: nil,
                                 hasDone: true,                 // conclude payment
                                showDone: .prominent,       // TODO: isKYC ? .bordered : .prominent
                                     url: nil,
                             withActions: false)
        } else if depositStarted {
            let message = String(localized: "Depositing...", comment: "loading")
            LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                .navigationBarBackButtonHidden(true)
                .interactiveDismissDisabled()           // can only use "Abort" button to dismiss
                .safeAreaInset(edge: .bottom) {
                    let buttonTitle = String(localized: "Abort", comment: "deposit")
                    Button(buttonTitle) { dismissTop(stack.push()) }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
        } else {
            let count = controller.balances.count
            let _ = symLog.log("count = \(count)")
            let currencySymbol = currencyInfo.symbol
            let navA11y = DepositAmountView.navTitle(currencyInfo.name, true)          // always include currency for a11y
            let navTitle = DepositAmountView.navTitle(currencySymbol, currencyInfo.hasSymbol)
            let scrollView = ScrollView {
                if let label {
                    Text("to \(label)")
                        .talerFont(.picker)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                if count > 1 {
                    ScopePicker(stack: stack.push(),
                                value: $balanceIndex,
                          onlyNonZero: true)                                        // can only send what exists
                    { index in
                        balanceIndex = index
                        balance = controller.balances[index]
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }   // TODO: else show static text?
                DepositAmountView(stack: stack.push(),
                                balance: $balance,
                           balanceIndex: $balanceIndex,
                         amountLastUsed: $amountLastUsed,
                       amountToTransfer: $amountToTransfer,
                        amountAvailable: amountAvailable,
                         depositStarted: depositStarted
                ) {
                    if let balance {
                        startDeposit(balance.scopeInfo)
                    }
                }
                    .onAppear {
                        DebugViewC.shared.setViewID(VIEW_DEPOSIT, stack: stack.push())
                        symLog.log("❗️ onAppear")
                    }
                    .onDisappear {
                        symLog.log("❗️ onDisappear")
                    }
            } // ScrollView
                .navigationTitle(navTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FullBackground())
//              .ignoresSafeArea(.keyboard, edges: .bottom)
                .task {
                    setVoice(to: nil)
                    await viewDidLoad()
                }
                .task(id: balanceIndex + (1000 * controller.currencyTicker)) { await newBalance() }

            if #available(iOS 16.4, *) {
                scrollView.toolbar(.hidden, for: .tabBar)
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                scrollView
            }
        } // else
    }
}
