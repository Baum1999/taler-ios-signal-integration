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
import AVFoundation

/// This view shows the list of balances / currencies, each in its own section
struct BalancesListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?                      // pass down to TransactionsListView
    @Binding var selectedIndex: Int?
    @Binding var reloadTransactions: Int
    @Binding var qrButtonTapped: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary = EMPTYSTRING
    @Namespace var namespace

    private static func className() -> String {"\(self)"}

    func refresh() async {
        controller.hapticNotification(.success)
        symLog.log("refreshing balances")
        await controller.loadBalances(stack.push("refreshing balances"), model)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            let count = controller.balances.count
            if controller.balances.isEmpty {
                WalletEmptyView(stack: stack.push("isEmpty"))
                    .refreshable {
                        await refresh()
                    }
            } else {
                /// In standard mode, selectedBalance just sets a "preference" which balance to pre-select for Actions.
                ///   However, the user can select another balance (with the picker) in each action
                /// In OIM mode, the user selects a balance 'here' (in OIMView) when tapping on a savings box (representing the balance)
                Group {
                    List(controller.balances, id: \.self) { balance in
                        BalancesSectionView(stack: stack.push("\(balance.scopeInfo.currency)"),
                                          balance: balance,                     // this is the currency to be used
                                  selectedBalance: $selectedBalance,            // set in TransactionsListView
                                     sectionCount: count,
                                 amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                          summary: $summary,
                               reloadTransactions: $reloadTransactions)
                    }
                    .onAppear() {
                        DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
                        selectedBalance = nil                                   // reset
                    }
                    .listStyle(myListStyle.style).anyView
                    .refreshable {
                        await refresh()
                    }
                }
#if OIM
                .overlay {
                  if #available(iOS 16.4, *) {
                    if controller.oimModeActive {
                        OIMView(stack: stack.push(),
                      selectedBalance: $selectedBalance,                    // set to user choice
                        selectedIndex: $selectedIndex,
                       qrButtonTapped: $qrButtonTapped)
                        .environmentObject(NamespaceWrapper(namespace))     // keep OIMviews apart
                    }
                  }
                }
#endif
            }
        }
    }
}
