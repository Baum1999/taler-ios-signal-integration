/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
//import SymLog

struct BalancesPendingRowV: View {
//    let symLog: SymLogV?            // inherited from BalancesSectionView
    let stack: CallStack
    let balance: Balance
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    let selectedChestIndex: Int?
    @Binding var pendingTransactions: [TalerTransaction]
    let reloadPending: (_ stack: CallStack) async -> ()

    @ViewBuilder func pendingRowLabel() -> some View {
        let pendingIncoming = balance.pendingIncoming
        let hasIncoming = !pendingIncoming.isZero
        let pendingOutgoing = balance.pendingOutgoing
        let hasOutgoing = !pendingOutgoing.isZero

        let needsKYCin = balance.flags.contains(.incomingKyc)
        let needsKYCout = balance.flags.contains(.outgoingKyc)
        let shouldConfirm = balance.flags.contains(.incomingConfirmation)
        let needsKYC =  needsKYCin || needsKYCout
        let needsKYCStr = String(localized: ". Legitimization required", comment: "a11y")
        let needsConfStr = String(localized: ". Needs bank confirmation", comment: "a11y")

        VStack(spacing: 6) {
            if hasIncoming {
                PendingRowView(scope: balance.scopeInfo,
                              amount: pendingIncoming,
                            incoming: true,
                       shouldConfirm: shouldConfirm,
                            needsKYC: needsKYCin)
            }
            if hasOutgoing {
                PendingRowView(scope: balance.scopeInfo,
                              amount: pendingOutgoing,
                            incoming: false,
                       shouldConfirm: false,
                            needsKYC: needsKYCout)
            }
            if !hasIncoming && !hasOutgoing {
                // should never happen - but DOES when wallet-core doesn't report P2P as pendingIncoming/pendingOutgoing
                Text("Some pending transactions")
                    .talerFont(.body)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(needsKYC && shouldConfirm ? needsKYCStr + needsConfStr :
                                             needsKYC ? needsKYCStr :
                                        shouldConfirm ? needsConfStr
                                                      : EMPTYSTRING)
        .accessibilityHint(String(localized: "Will go to Pending transactions.", comment: "a11y"))
    }

    var body: some View {
            let destination = TransactionsListView(stack: stack.push(),
                                                   scope: balance.scopeInfo,
                                                 balance: balance,
                                         selectedBalance: $selectedBalance,     // set in there
                                                navTitle: String(localized: "Pending", comment: "ViewTitle of TransactionList"),
                                            transactions: $pendingTransactions,
                                         reloadAllAction: reloadPending)
            NavigationLink(destination: destination) { pendingRowLabel() }
            //let _ = print("button: Pending Transactions: \(currency)")
    } // body
} // BalancesPendingRowV

// MARK: -
#if DEBUG
fileprivate struct BalancesPendingRowV_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer: View {
        @State private var previewTransactions: [TalerTransaction] = []
        @State private var previewD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
        @State private var selectedPreviewBalance: Balance? = nil
        var body: some View {
            let flags: [BalanceFlag] = [.incomingConfirmation]

            let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, currency: DEMOCURRENCY, url: DEMOEXCHANGE)
            let balance = Balance(scopeInfo: scopeInfo,
                                  available: Amount(currency: DEMOCURRENCY, cent:1000),
                            pendingIncoming: Amount(currency: DEMOCURRENCY, cent: 555),
                            pendingOutgoing: Amount(currency: DEMOCURRENCY, cent: 333),
                                      flags: flags)
            BalancesPendingRowV(//symLog: nil,
                                 stack: CallStack("Preview"),
                               balance: balance,
                       selectedBalance: $selectedPreviewBalance,
                    selectedChestIndex: nil,            // preview
                   pendingTransactions: $previewTransactions,
                         reloadPending: {stack in })
        }
    }

    @MainActor
    static var previews: some View {
        List {
            Section {
                BindingViewContainer()
            }
        }
    }
}
#endif
