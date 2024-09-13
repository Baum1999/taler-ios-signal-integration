/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
//import SymLog

struct BalancesPendingRowV: View {
//    let symLog: SymLogV?            // inherited from BalancesSectionView
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    let balance: Balance
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    @Binding var pendingTransactions: [Transaction]
    let reloadPending: (_ stack: CallStack) async -> ()
    let reloadOneAction: ((_ transactionId: String, _ viewHandles: Bool) async throws -> Transaction)?

    @ViewBuilder func pendingRowLabel() -> some View {
        let pendingIncoming = balance.pendingIncoming
        let hasIncoming = !pendingIncoming.isZero
        let pendingOutgoing = balance.pendingOutgoing
        let hasOutgoing = !pendingOutgoing.isZero

        let needsKYCin = balance.flags.contains(.incomingKyc)
        let needsKYCout = balance.flags.contains(.outgoingKyc)
        let shouldConfirm = balance.flags.contains(.incomingConfirmation)
        let needsKYC =  needsKYCin || needsKYCout
        let needsKYCStr = String(localized: ". Needs K Y C", comment: "VoiceOver")
        let needsConfStr = String(localized: ". Needs bank confirmation", comment: "VoiceOver")

        VStack(spacing: 6) {
            if hasIncoming {
                PendingRowView(currencyInfo: $currencyInfo,
                                     amount: pendingIncoming,
                                   incoming: true,
                              shouldConfirm: shouldConfirm,
                                   needsKYC: needsKYCin)
            }
            if hasOutgoing {
                PendingRowView(currencyInfo: $currencyInfo,
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
        .accessibilityHint(String(localized: "Will go to Pending transactions."))
    }

    var body: some View {
        if let reloadOneAction {
            let destination = LazyView {
                TransactionsListView(stack: stack.push(),
                                   balance: balance,
                           selectedBalance: $selectedBalance,
                              currencyInfo: $currencyInfo,
                                  navTitle: String(localized: "Pending", comment: "ViewTitle of TransactionList"),
                                 scopeInfo: balance.scopeInfo,
                              transactions: $pendingTransactions,
                           reloadAllAction: reloadPending,
                           reloadOneAction: reloadOneAction)
            }
            NavigationLink(destination: destination, label: { pendingRowLabel() })
            //let _ = print("button: Pending Transactions: \(currency)")
        } else { // just for Preview
            NavigationLink(destination: EmptyView(), label: { pendingRowLabel() })
        }
    } // body
} // BalancesPendingRowV

// MARK: -
#if DEBUG
fileprivate struct BalancesPendingRowV_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer: View {
        @State private var previewTransactions: [Transaction] = []
        @State private var currencyInfoD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
        @State private var selectedBalance: Balance? = nil
        var body: some View {
            let flags: [BalanceFlag] = [.incomingConfirmation]

            let scopeInfo = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange, url: DEMOEXCHANGE, currency: DEMOCURRENCY)
            let balance = Balance(scopeInfo: scopeInfo,
                                  available: Amount(currency: DEMOCURRENCY, cent:1000),
                            pendingIncoming: Amount(currency: DEMOCURRENCY, cent: 555),
                            pendingOutgoing: Amount(currency: DEMOCURRENCY, cent: 333),
                                      flags: flags)
            BalancesPendingRowV(//symLog: nil,
                                 stack: CallStack("Preview"),
                          currencyInfo: $currencyInfoD,
                               balance: balance,
                       selectedBalance: $selectedBalance,
                   pendingTransactions: $previewTransactions,
                         reloadPending: {stack in },
                       reloadOneAction: nil)
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
