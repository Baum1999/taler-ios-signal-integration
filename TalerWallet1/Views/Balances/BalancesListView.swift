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
import AVFoundation

/// This view shows the list of balances / currencies, each in its own section
struct BalancesListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var selectedBalance: Balance?
//    @Binding var shouldReloadPending: Int
    @Binding var shouldReloadBalances: Int

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary = EMPTYSTRING

    private static func className() -> String {"\(self)"}

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            let count = controller.balances.count
            if controller.balances.isEmpty {
                WalletEmptyView(stack: stack.push("isEmpty"))
            } else {
                List(controller.balances, id: \.self) { balance in
                    BalancesSectionView(stack: stack.push("\(balance.scopeInfo.currency)"),
                                      balance: balance,                     // this is the currency to be used
                              selectedBalance: $selectedBalance,
                                 sectionCount: count,
                             amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                      summary: $summary,
                         shouldReloadBalances: $shouldReloadBalances)
                }
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
                    selectedBalance = nil
                }
                .listStyle(myListStyle.style).anyView
            }
        }
#if REFRESHABLE
        .refreshable {  // already async
            controller.hapticNotification(.success)
            symLog.log("refreshing balances")
            await controller.loadBalances(stack.push("refreshing balances"), model)
        }
#endif
    }
}
