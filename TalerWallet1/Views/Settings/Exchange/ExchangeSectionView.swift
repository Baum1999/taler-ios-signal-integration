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

/// This view shows the currency name in an exchange section
///         currency
struct ExchangeSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance
    let thousand: Int           // index of balance times 1000 (MAXEXCHANGES per currency)
    let developerMode: Bool
    let deleteTask: () -> Void

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true

    @State private var exchanges: [Exchange] = []
    @State private var reloadTransactions: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var withDrawStarted = false
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false
    @State private var global: Bool = false
    @State private var legacy: Bool = false

    @MainActor
    private func viewDidLoad() async {
        if let exc = try? await model.listExchanges(scope: balance.scopeInfo) {
            if let exchange = exc.first {
                global = exchange.scopeInfo.type == .global
                legacy = exchange.scopeInfo.type == .exchangeLegacyKeys
            }
            withAnimation { exchanges = exc }
        }
    }

    @MainActor
    private func currencyTickerChanged(_ scopeInfo: ScopeInfo) async {
        symLog.log("task \(didDelete ? 1 : 0)")
        currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
    }

    /// purge must never be remembered - it deletes the exchange even if it still holds coins,
    ///  so it may only ever come from the escalated alert (warningText2/3) which says so
    @MainActor
    private func deleteExchange(purge: Bool) {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
            if let exchange = exchanges.first {
                let baseUrl = exchange.exchangeBaseUrl
                if let _ = try? await model.deleteExchange(url: baseUrl, purge: purge, viewHandles: !purge) {
                    symLog.log("deleted \(baseUrl.trimURL)")
                    didDelete = true             // change button text
                    NotificationCenter.default.post(name: .ExchangeDeleted, object: nil, userInfo: nil)
                    NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
                    demoHints = true
                    deleteTask()
                } else {
                    showAlert = true
                    disabled = false
                }
            }
        }
    }

    @MainActor
    private func setGlobal() {
        if let exchange = exchanges.first {
            let scope = exchange.scopeInfo
            Task {
                if scope.type != .global {
                    try? await model.addGlobalCurrencyExchange(currency: exchange.scopeInfo.currency,
                                                                baseUrl: exchange.exchangeBaseUrl,
                                                              masterPub: exchange.masterPub ?? EMPTYSTRING)
                } else {
                    try? await model.rmvGlobalCurrencyExchange(currency: exchange.scopeInfo.currency,
                                                                baseUrl: exchange.exchangeBaseUrl,
                                                              masterPub: exchange.masterPub ?? EMPTYSTRING)
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
        Section {
            ForEachWithIndex(array: exchanges) { index, exchange in
                let _ = symLog.log("Index: \(thousand + index)")
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
                                index: thousand + index + 1,
                        developerMode: developerMode)
                .listRowSeparator(.hidden)
            }
            if developerMode && (DEMOCURRENCY == currency || TESTCURRENCY == currency) {
                SettingsToggle(name: String("Global"), value: $global.onChange({ isGlobal in
                    setGlobal()
                }),             id1: "global",
                        description: String("Treat this as a global exchange"))
                .listRowSeparator(.hidden)
                SettingsToggle(name: String("Fake no fees"), value: $fakeNoFees,
                                id1: "fakeNoFees",
                        description: String("Remove fee and gros from details"))
            }
            if DEMOCURRENCY == currency {
                let title = String(localized: "LinkTitle_Test_Money2", defaultValue: "Get more demo cash")
                Button(title) {
                    withDrawStarted = true    // don't run twice
                    Task { // runs on MainActor
                        let amount = Amount(currency:  DEMOCURRENCY, cent: 1000)
                        symLog.log("Withdraw 10 KUDOS")
                        try? await model.loadTestKudos(0, amount: amount)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withDrawStarted = false
                        }
                    }
                }
                    .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, disabled: withDrawStarted, aligned: .center))
                    .disabled(withDrawStarted)

                SettingsToggle(name: String(localized: "Demo Hints"), value: $demoHints,
                                id1: "demoHints",
                        description: String(localized: "Show hints for demo money"))
                    .listRowSeparator(.hidden)

                let bankingHint = String(localized: "Since the demo bank supports the Taler integration, you can start a withdrawal directly on the")
                let linkTitle = String(localized: "LinkTitle_DEMOBANK", defaultValue: "Demo Bank Website")
                if demoHints {
                    VStack {
                        if !minimalistic {
                            Text(bankingHint)
                        }
                        Link(linkTitle, destination: URL(string: DEMOBANK)!)
                            .buttonStyle(TalerButtonStyle(type: .bordered, narrow: false, aligned: .center))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(bankingHint + SPACE + linkTitle)
                    .padding(.top)
                    .listRowSeparator(.hidden)
                }
            }
            let dialect = exchanges.first?.bankComplianceLanguage
            let buttonTitle = localizedString(.deleteExchange, forDialect: dialect)
            let warningText1 = localizedString(.warningText1, forDialect: dialect)
            let warningText2 = localizedString(.warningText2, forDialect: dialect)
            let warningText3 = localizedString(.warningText3, forDialect: dialect, currency)
            WarningButton(warningText: warningText1,
                          buttonTitle: buttonTitle,
                           buttonIcon: "trash",
                                 role: .destructive,       // optional: use WalletColors().errorColor
                             disabled: $disabled,
                               action: { deleteExchange(purge: false) })
            .padding(.top)
            .alert(warningText2, isPresented: $showAlert, actions: {
                Button("Cancel", role: .cancel) {
                    showAlert = false
                }
                Button("Deposit") {
                    showAlert = false
//                    dismissTop(stack.push())              don't do this - will dismiss the Deposit view
                    NotificationCenter.default.post(name: .DepositAction, object: nil)  // will trigger NavigationLink
                }
                Button(buttonTitle) {
                    deleteExchange(purge: true)
                    showAlert = false
                }
            }, message: {
                Text(warningText3)
            })
        } header: {
            BarGraphHeader(stack: stack.push(),
                           scope: scopeInfo,
              reloadTransactions: $reloadTransactions)
        }
        .task { await viewDidLoad() }
        .task(id: controller.currencyTicker) { await currencyTickerChanged(scopeInfo) }
        .onDisappear() {
            disabled = false
        }
    }
}
