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
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var exchanges: [Exchange] = []
    @State private var shouldReloadBalances: Int = 0
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
            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                             exchange: exchange)
                .listRowSeparator(.hidden)
            }
            if developerMode && (DEMOCURRENCY == currency || TESTCURRENCY == currency) {
                SettingsToggle(name: String(localized: "Global"), value: $global.onChange({ isGlobal in
                    setGlobal()
                }),             id1: "global",
                        description: minimalistic ? nil : String(localized: "Treat this as a global exchange"))
                .listRowSeparator(.hidden)
                SettingsToggle(name: String(localized: "Fake no fees"), value: $fakeNoFees, id1: "fakeNoFees",
                               description: minimalistic ? nil : String(localized: "Remove fee and gros from details"))
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
                    .accessibilityLabel(bankingHint + " " + linkTitle)
                    .padding(.top)
                    .listRowSeparator(.hidden)
                }
            }

            let buttonTitle = String(localized: "Exchange.Delete", defaultValue: "Delete payment service", comment: "Action button")
            let warningText1 = String(localized: "Are you sure you want to delete this payment service?")
            let warningText2 = String(localized: "This payment service is in use. Delete anyway?")
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
                Text("You will loose all \(currency) of this payment service")
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
