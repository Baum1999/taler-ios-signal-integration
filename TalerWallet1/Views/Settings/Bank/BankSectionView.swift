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
struct BankSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let account: KnownBankAccountsInfo

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("demoHints") var demoHints: Bool = true
    @AppStorage("fakeNoFees") var fakeNoFees: Bool = true

    @State private var shouldReloadBalances: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var showAlert: Bool = false
    @State private var purge: Bool = false
    @State private var global: Bool = false

    @MainActor
    private func viewDidLoad() async {
//        if let exc = try? await model.listExchanges(scope: balance.scopeInfo) {
//            withAnimation { exchanges = exc }
//        }
    }

    @MainActor
    private func deleteAccount() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
//            if let _ = try? await model.deleteExchange(url: baseUrl, purge: purge, viewHandles: !purge) {
//                purge = false
//                symLog.log("deleted \(baseUrl.trimURL)")
//                didDelete = true             // change button text
//                NotificationCenter.default.post(name: .ExchangeDeleted, object: nil, userInfo: nil)
//                NotificationCenter.default.post(name: .BalanceChange, object: nil, userInfo: nil)
//                demoHints = true
//            } else {
//                purge = true
//                showAlert = true
//                disabled = false
//            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Section {
            if let alias = account.alias {
                Text(alias)
            }
            let payURL = URL(string: account.paytoUri)
            if let queryParameters = payURL?.queryParameters {
                let name = if let rcv = queryParameters["receiver-name"] {
                    rcv.replacingOccurrences(of: "+", with: " ")
                } else {
                    EMPTYSTRING
                }
                Text("Holder: \(name)")


//                let amountStr = queryParameters["amount"] ?? EMPTYSTRING
//                let messageStr = queryParameters["message"] ?? EMPTYSTRING
//                let senderStr = queryParameters["sender-name"] ?? EMPTYSTRING

            }

            let method = if let iban = payURL?.iban {
                Text("IBAN: \(iban)")
            } else if let xTaler = payURL?.xTaler {
                Text("TALER: \(xTaler)")
            } else {
                Text("unknown payment method")
            }
            method

            let kyc = account.kycCompleted ? String(localized: "verified")
                                           : String(localized: "not yet verified")
            Text(kyc)
                .padding(.leading)

            if account.currencies.count == 1 {
                let currency = account.currencies[0]
                Text("Currency: \(currency)")
            } else {
                Text("Currencies:")
                ForEach (account.currencies, id: \.self) { currency in
                    Text(currency)
                        .padding(.leading)
                }
            }
            Button {
                deleteAccount()
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
                .buttonStyle(TalerButtonStyle(type: .bordered, disabled: disabled))
                .disabled(disabled)
        } header: {
        }
        .task { await viewDidLoad() }
//        .task(id: controller.currencyTicker) { await currencyTickerChanged(scopeInfo) }
        .onDisappear() {
            disabled = false
            purge = false
        }
    }
}
