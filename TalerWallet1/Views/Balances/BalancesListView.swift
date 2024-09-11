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
    @Binding var balances: [Balance]
//    @Binding var shouldReloadPending: Int
    @Binding var shouldReloadBalances: Int
    let cameraAction: () -> Void

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var lastReloadedBalances = 0
    @State private var actionSelected: Int? = nil
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary: String = ""
    @State private var myExchange: Exchange? = nil

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

    private static func className() -> String {"\(self)"}

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scope = ScopeInfo(type: ScopeInfo.ScopeInfoType.exchange,
                            noFees: false,
                               url: DEMOEXCHANGE,
                          currency: DEMOCURRENCY)
        let sendDest = LazyView {
            SendAmount(stack: stack.push("\(Self.className())()"),
                    balances: balances,
//              currencyInfo: $currencyInfo,
//           amountAvailable: amountAvailable,
                   available: nil,
            amountToTransfer: $amountToTransfer,        // with correct currency
                     summary: $summary,
                   scopeInfo: scope,
                cameraAction: cameraAction)
        }

        let requestDest = LazyView {
            RequestPayment(stack: stack.push("\(Self.className())()"),
//                  currencyInfo: $currencyInfo,
                amountToTransfer: $amountToTransfer,    // with correct currency
                         summary: $summary,
                       scopeInfo: scope,
                    cameraAction: cameraAction)
        }

        let depositDest = LazyView {
            DepositIbanV(stack: stack.push(),
//                currencyInfo: $currencyInfo,
                      feeLabel: nil,
                  feeIsNotZero: nil,
//             amountAvailable: amountAvailable,
//                 depositIBAN: $depositIBAN,
//               accountHolder: $accountHolder,
              amountToTransfer: $amountToTransfer)
        }

        let manualWithdrawDest = LazyView {
            ManualWithdraw(stack: stack.push(),
//                  currencyInfo: $currencyInfo,
                         isSheet: false,
                       scopeInfo: scope,
                        exchange: $myExchange,
                amountToTransfer: $amountToTransfer)
        }

        Group { // necessary for .backslide transition (bug in SwiftUI)
            let count = balances.count
            if balances.isEmpty {
                WalletEmptyView(stack: stack.push("isEmpty"))
            } else {
                List(balances, id: \.self) { balance in
                    BalancesSectionView(stack: stack.push("\(balance.scopeInfo.currency)"),
                                      balance: balance,                     // this is the currency to be used
                                 sectionCount: count,
                             amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                      summary: $summary,
                         shouldReloadBalances: $shouldReloadBalances,
                                 cameraAction: cameraAction)
                }
                .onAppear() {
                    DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
                    controller.frontendState = 0                            // neutral
                }
                .listStyle(myListStyle.style).anyView
            }
        }
        .background( Group {
            NavigationLink(destination: sendDest, tag: 1, selection: $actionSelected)
            { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: requestDest, tag: 2, selection: $actionSelected)
            { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: depositDest, tag: 3, selection: $actionSelected)
            { EmptyView() }.frame(width: 0).opacity(0).hidden()
            NavigationLink(destination: manualWithdrawDest, tag: 4, selection: $actionSelected)
            { EmptyView() }.frame(width: 0).opacity(0).hidden()
        })
        .onNotification(.SendAction) { actionSelected = 1 }
        .onNotification(.RequestAction) { actionSelected = 2 }
        .onNotification(.DepositAction) { actionSelected = 3 }
        .onNotification(.WithdrawAction) { actionSelected = 4 }
#if REFRESHABLE
        .refreshable {  // already async
            symLog.log("refreshing balances")
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
