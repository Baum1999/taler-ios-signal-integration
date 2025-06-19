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

/// This view shows the currency name in an exchange section
///         currency
struct ExchangeSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance
    let thousand: Int

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var exchanges: [Exchange] = []
    @State private var reloadTransactions: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false
    @State private var purge: Bool = false
    @State private var global: Bool = false

    @MainActor
    private func viewDidLoad() async {
        if let exc = try? await model.listExchanges(scope: balance.scopeInfo) {
            if exc.count > 0 {
                let exchange = exc[0]
                global = exchange.scopeInfo.type == .global
            }
            withAnimation { exchanges = exc }
        }
    }

    @MainActor
    private func currencyTickerChanged(_ scopeInfo: ScopeInfo) async {
        symLog.log("task \(didDelete ? 1 : 0)")
        currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
    }

    @MainActor
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
                demoHints = true
            } else {
                purge = true
                showAlert = true
                disabled = false
            }
          }
        }
    }

    @MainActor
    private func setGlobal() {
        if exchanges.count > 0 {
            let exchange = exchanges[0]
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
            ForEachWithIndex(data: exchanges) { index, exchange in
                let _ = symLog.log("Index: \(thousand + index)")
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange,
                                index: thousand + index + 1)
                .listRowSeparator(.hidden)
            }
            if developerMode && (DEMOCURRENCY == currency || TESTCURRENCY == currency) {
                SettingsToggle(name: String("Global"), value: $global.onChange({ isGlobal in
                    setGlobal()
                }),             id1: "global",
                        description: minimalistic ? nil : String("Treat this as a global exchange"))
                .listRowSeparator(.hidden)
                SettingsToggle(name: String("Fake no fees"), value: $fakeNoFees, id1: "fakeNoFees",
                               description: minimalistic ? nil : String("Remove fee and gros from details"))
            }
            if DEMOCURRENCY == currency {
                SettingsToggle(name: String(localized: "Demo Hints"), value: $demoHints, id1: "demoHints",
                        description: minimalistic ? nil : String(localized: "Show hints for demo money"))
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
                               action: deleteExchange)
            .padding(.top)
            .alert(warningText2, isPresented: $showAlert, actions: {
                Button("Cancel", role: .cancel) {
                    showAlert = false
                }
                Button("Deposit") {
                    // TODO: Go to "Deposit" view
                    showAlert = false
                }
                Button(buttonTitle) {
                    deleteExchange()
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
            purge = false
        }
    }
}
