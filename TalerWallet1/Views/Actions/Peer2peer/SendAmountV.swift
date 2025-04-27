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

// Called when tapping [􁉇Send]
struct SendAmountV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let selectedBalance: Balance?           // coming from transaction list or OIM
    @Binding var amountLastUsed: Amount
    @Binding var summary: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    @State private var balanceIndex = 0
    @State private var balance: Balance? = nil      // nil only when balances == []
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // GetMaxPeerPushAmount
    @State private var buttonSelected = false
    @Namespace var namespace

    @MainActor
    private func viewDidLoad() async {
        let balances = controller.balances
        if let selectedBalance {
            if selectedBalance.available.isZero {
                // find another balance
                balance = Balance.firstNonZero(controller.balances)
            } else {
                balance = selectedBalance
            }
        } else {
            balance = Balance.firstNonZero(controller.balances)
        }
        if let balance {
            balanceIndex = balances.firstIndex(of: balance) ?? 0
        } else {
            balanceIndex = 0
            balance = (balances.count > 0) ? balances[0] : nil
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
                amountAvailable = try await model.getMaxPeerPushDebitAmount(scope)
            } catch {
                // TODO: Error
                amountAvailable = balance.available
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let currencySymbol = currencyInfo.symbol
        let navA11y = SendAmountView.navTitle(currencyInfo.name)                // always include currency for a11y
        let navTitle = SendAmountView.navTitle(currencySymbol, currencyInfo.hasSymbol)
        let count = controller.balances.count
        let _ = symLog.log("count = \(count)")
        let scrollView = ScrollView {
            if count > 0 {
                ScopePicker(value: $balanceIndex,
                      onlyNonZero: true)                                        // can only send what exists
                { index in
                    balanceIndex = index
                    balance = controller.balances[index]
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            if let balance {
                SendAmountView(stack: stack.push(),
                             balance: balance,
                      buttonSelected: $buttonSelected,
                      amountLastUsed: $amountLastUsed,
                    amountToTransfer: $amountToTransfer,
                     amountAvailable: $amountAvailable,
                             summary: $summary)
            } else {    // TODO: Error no balance - Yikes
                Text("No balance. There seems to be a problem with the database...")
            }
        } // ScrollView
            .navigationTitle(navTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .task { await viewDidLoad() }
            .task(id: balanceIndex + (1000 * controller.currencyTicker)) { await newBalance() }
#if OIM
            .overlay {
                if controller.oimModeActive {
                    OIMEditView(stack: stack.push(),
                                scope: balance?.scopeInfo,
                               amount: $amountToTransfer,
                            available: $amountAvailable,
                       buttonSelected: $buttonSelected)
                    .environmentObject(NamespaceWrapper(namespace))             // keep OIMviews apart
                }
            }
#endif
        if #available(iOS 16.4, *) {
            scrollView.toolbar(.hidden, for: .tabBar)
                .scrollBounceBehavior(.basedOnSize)
        } else {
            scrollView
        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct Preview_Content: View {
    @State private var amountToPreview = Amount(currency: DEMOCURRENCY, cent: 510)
    @State private var summary: String = EMPTYSTRING
    @State private var currencyInfoL: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
    @State private var noBalance: Balance? = nil

    var body: some View {
        let amount = Amount(currency: DEMOCURRENCY, cent: 1000)
        let pending = Amount(currency: DEMOCURRENCY, cent: 0)
        let scope = ScopeInfo.zero(DEMOCURRENCY)
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                       masterPub: "masterPub",
                                       scopeInfo: scope,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        let balance = Balance(scopeInfo: scope,
                              available: amount,
                        pendingIncoming: pending,
                        pendingOutgoing: pending,
                                  flags: [])
        SendAmountV(stack: CallStack("Preview"),
          selectedBalance: noBalance,
           amountLastUsed: $amountToPreview,
                  summary: $summary)
    }
}

fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @StateObject private var controller = Controller.shared
        var body: some View {
            Preview_Content()
                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
