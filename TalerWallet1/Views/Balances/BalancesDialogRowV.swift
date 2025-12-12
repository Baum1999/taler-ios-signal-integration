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

struct BalancesDialogRowV: View {
//    let symLog: SymLogV?            // inherited from BalancesSectionView
    let stack: CallStack
    let balance: Balance
    @Binding var selectedBalance: Balance?          // <- return here the balance when we go to Transactions
    @Binding var scannedTransactions: [TalerTransaction]
    let reloadScanned: (_ stack: CallStack) async -> ()

    @AppStorage("oimEuro") var oimEuro: Bool = false

    @ViewBuilder func pendingRowLabel() -> some View {

        VStack(spacing: 6) {
                Text("Scanned transactions")
                    .talerFont(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Will go to Scanned transactions.", comment: "a11y"))
    }

    var body: some View {
            let destination = TransactionsListView(stack: stack.push(),
                                                   scope: balance.scopeInfo,
                                                 balance: balance,
                                         selectedBalance: $selectedBalance,     // set in there
                                                navTitle: String(localized: "Scanned", comment: "ViewTitle of TransactionList"),
                                                 oimEuro: oimEuro,
                                            transactions: $scannedTransactions,
                                         reloadAllAction: reloadScanned)
            NavigationLink(destination: destination) { pendingRowLabel() }
            //let _ = print("button: Pending Transactions: \(currency)")
    } // body
} // BalancesDialogRowV

// MARK: -
#if DEBUG
fileprivate struct BalancesDialogRowV_Previews: PreviewProvider {
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
            BalancesDialogRowV(//symLog: nil,
                                 stack: CallStack("Preview"),
                               balance: balance,
                       selectedBalance: $selectedPreviewBalance,
                   scannedTransactions: $previewTransactions,
                         reloadScanned: {stack in })
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
