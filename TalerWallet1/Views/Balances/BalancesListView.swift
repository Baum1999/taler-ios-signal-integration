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
import AVFoundation

/// This view shows the list of balances / currencies, each in its own section
struct BalancesListView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let title: String
    @Binding var selectedBalance: Balance?                      // set in TransactionsListView
    @Binding var reloadTransactions: Int
    @Binding var qrButtonTapped: Bool

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("oimEuro") var oimEuro: Bool = false

    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var summary = EMPTYSTRING

    @State private var historyTapped: Int? = nil
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
//        Group {
            if controller.balances.isEmpty {
                let talerLogo = HStack(spacing: 2) {
                    Image(TALER_LOGO_FULL)
//                        .border(Color.gray, width: 1)
//                    Text("TALER Wallet")
                    Text("Wallet")
//                        .font(.logo(27, weight: .medium))
                        .font(.logo("Atkinson Hyperlegible Next", size: 27, weight: .medium))
                        .kerning(1.0)
                }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(Text("Taler Wallet", comment: "a11y"))

                WalletEmptyView(stack: stack.push("isEmpty"))
//                    .navigationTitle("Taler Wallet")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            talerLogo
                                .padding(.top, 10)
                        }
                    }
                    .refreshable {
                        await refresh()
                    }
            } else {
                /// In standard mode, selectedBalance just sets a "preference" which balance to pre-select for Actions.
                ///   However, the user can select another balance (with the picker) in each action
                /// In OIM mode, the user selects a balance 'here' (in OIMView) when tapping on a savings box (representing the balance)
                let count = controller.balances.count
                Group {
                    List {
                        if !controller.haveProdBalance && !controller.defaultExchanges.isEmpty {
                            ProdSectionView(stack: stack.push(), isEmpty: false, disabled: false)
                        }
                        ForEach(Array(controller.balances.enumerated()), id: \.element) { index, balance in
                            BalancesSectionView(stack: stack.push("\(balance.scopeInfo.currency)"),
                                              balance: balance,                     // this is the currency to be used
                                      selectedBalance: $selectedBalance,            // set in TransactionsListView
                                         balanceIndex: index,
                                         sectionCount: count,
                                     amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                              summary: $summary,
                                        historyTapped: $historyTapped,
                                   reloadTransactions: $reloadTransactions)
                        }
                    }
                    .onAppear() {
                        DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
                        if !controller.oimModeActive {
                            print("🚩BalancesListView.onAppear() reset selectedBalance")
//                            if count > 1 {
                                selectedBalance = nil                           // reset
//                            }
                        }
                    }
                    .listStyle(myListStyle.style).anyView
                    .refreshable {
                        await refresh()
                    }
                }.navigationTitle(title)
                .onChange(of: controller.oimModeActive) { oimModeActive in
                    if !oimModeActive {
                        print("🚩BalancesListView.onChange(of: oimModeActive) reset selectedBalance")
//                        if count > 1 {
                            selectedBalance = nil                               // reset
//                        }
                    }
                }
#if OIM
                .overlay { if #available(iOS 16.4, *) {
                    if controller.oimModeActive {
                        OIMbalances(stack: stack.push(),
                          selectedBalance: $selectedBalance,                    // set to user choice
                           qrButtonTapped: $qrButtonTapped,
                            historyTapped: $historyTapped,
                                  oimEuro: oimEuro)
                        .environmentObject(NamespaceWrapper(namespace))         // keep OIMviews apart
                    }
                } }
#endif
            } // not empty
//        }
    }
}
