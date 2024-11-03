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

/// This view shows the currency name in an exchange section
///         currency
struct ExchangeSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("hideSpendingHint") var hideSpendingHint: Bool = false

    @State private var exchanges: [Exchange] = []
    @State private var shouldReloadBalances: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false
    @State private var purge: Bool = false

//    func amountAvailable(_ exchange: Exchange?, currency: String?) -> Amount? {
//        if let exchange {
//            for balance in balances {
//                if let baseUrl = balance.scopeInfo.url {
//                    if baseUrl == exchange.exchangeBaseUrl {
//                        return balance.available
//                    }
//                } else if let currency {
//                    if currency == balance.scopeInfo.currency {
//                        return balance.available
//                    }
//                }
//            }
//        }
//        return nil
//    }

    private func viewDidLoad() async {
        if let exc = try? await model.listExchangesM(scope: balance.scopeInfo) {
            withAnimation { exchanges = exc }
        }
    }
    private func currencyTickerChanged(_ scopeInfo: ScopeInfo) async {
        symLog.log("task \(didDelete ? 1 : 0)")
        currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
    }
    private func deleteExchange() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
          if exchanges.count > 0 {
            let exchange = exchanges[0]
            let baseUrl = exchange.exchangeBaseUrl
            if let _ = try? await model.deleteExchange(url: baseUrl, purge: purge, viewHandles: !purge) {
                purge = false
                symLog.log("deleted \(baseUrl.trimURL)")
                didDelete = true             // change button text
                NotificationCenter.default.post(name: .ExchangeDeleted, object: nil, userInfo: nil)
                NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
                hideSpendingHint = false
            } else {
                purge = true
                showAlert = true
                disabled = false
            }
          }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scopeInfo = balance.scopeInfo
        let currency = scopeInfo.currency
//        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        Section {
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                         currencyInfo: $currencyInfo,
                             exchange: exchange)
                .listRowSeparator(.hidden)
            }
            if DEMOCURRENCY == currency {
                let bankingHint = String(localized: "Since the demo bank supports the Taler integration, you can start a withdrawal directly on the")
                let linkTitle = String(localized: "LinkTitle_DEMOBANK", defaultValue: "Demo Bank Website")
                VStack {
                    if !minimalistic {
                        Text(bankingHint)
                    }
                    Link(linkTitle, destination: URL(string: DEMOBANK)!)
                        .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(bankingHint + " " + linkTitle)
                .padding(.top)
                .listRowSeparator(.hidden)
            }

            let buttonTitle = String(localized: "Exchange.Delete", defaultValue: "Delete payment provider", comment: "Action button")
            let warningText1 = String(localized: "Are you sure you want to delete this payment provider?")
            let warningText2 = String(localized: "This payment provider is in use. Delete anyway?")
            WarningButton(warningText: warningText1,
                          buttonTitle: buttonTitle,
                           buttonIcon: "trash",
                                 role: .destructive,
                             disabled: $disabled,
                               action: deleteExchange)
            .padding(.top)
            .alert(warningText2, isPresented: $showAlert, actions: {
                Button("Cancel", role: .cancel) {
                    showAlert = false
                }
                Button(buttonTitle) {
                    deleteExchange()
                    showAlert = false
                }
            }, message: {
                Text("You will loose all \(currency) of this payment provider")
            })
        } header: {
            BarGraphHeader(stack: stack.push(),
                           scope: scopeInfo,
            shouldReloadBalances: $shouldReloadBalances)
        }
        .task { await viewDidLoad() }
        .task(id: controller.currencyTicker) { await currencyTickerChanged(scopeInfo) }
        .onDisappear() {
            disabled = false
            purge = false
        }
    }
}
