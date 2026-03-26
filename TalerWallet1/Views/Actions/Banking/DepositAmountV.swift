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

// Called from DepositSelectV
struct DepositAmountV: View {
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

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
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
            if count > 0 {
                ScopePicker(stack: stack.push(),
                            value: $balanceIndex,
                      onlyNonZero: true)                                        // can only send what exists
                { index in
                    balanceIndex = index
                    balance = controller.balances[index]
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            DepositAmountView(stack: stack.push(),
                            balance: $balance,
                       balanceIndex: $balanceIndex,
                     amountLastUsed: $amountLastUsed,
                   amountToTransfer: $amountToTransfer,
                    amountAvailable: amountAvailable,
                           paytoUri: paytoUri)
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
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
    }
}
