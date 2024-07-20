/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Overview when there's more than 1 currency/exchange
 *
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

/// This view shows the list of balances / currencies, each in its own section
struct OverviewListV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balances: [Balance]
//    @Binding var shouldReloadPending: Int
    @Binding var shouldReloadBalances: Int
    let cameraAction: () -> Void

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var lastReloadedBalances = 0
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary: String = ""

    /// runs on MainActor if called in some Task {}
    @discardableResult
    private func reloadBalances(_ stack: CallStack, _ invalidateCache: Bool) async -> Int? {
        if invalidateCache {
            model.cachedBalances = nil
        }

        if let reloaded = try? await model.balancesM(stack.push()) {
            let count = reloaded.count
            balances = reloaded         // redraw
            return count
        }

        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group { // necessary for .backslide transition (bug in SwiftUI)
            let count = balances.count
            if balances.isEmpty {
                WalletEmptyView(stack: stack.push("isEmpty"))
            } else {
                List(balances, id: \.self) { balance in
                    OverviewSectionV(stack: stack.push("\(balance.scopeInfo.currency)"),
                                   balance: balance,                     // this is the currency to be used
                              sectionCount: count,
                          amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                   summary: $summary,
                      shouldReloadBalances: $shouldReloadBalances)
                }
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_OVERVIEW, stack: stack.push("onAppear"))
                    controller.frontendState = 0                            // neutral
                }
                .listStyle(myListStyle.style).anyView
            }
        }
#if REFRESHABLE
        .refreshable {  // already async
            symLog?.log("refreshing balances")
            let count = await reloadBalances(stack.push("refreshing balances"), true)
            if let count, count > 0 {
                NotificationCenter.default.post(name: .BalanceReloaded, object: nil)
            }
        }
#endif
        .navigationBarItems(trailing: QRButton(action: cameraAction))
        .task(id: shouldReloadBalances) {
            symLog.log(".task shouldReloadBalances \(shouldReloadBalances)")
            let invalidateCache = (lastReloadedBalances != shouldReloadBalances)
            lastReloadedBalances = shouldReloadBalances
            await reloadBalances(stack.push(".task"), invalidateCache)
        } // task
    }
}
