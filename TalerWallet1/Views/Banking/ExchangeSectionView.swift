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
/// [Deposit Coins]  [Withdraw Coins]
struct ExchangeSectionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balances: [Balance]
    let exchange: Exchange
//    let exchanges: [Exchange]
//    @Binding var depositIBAN: String
//    @Binding var accountHolder: String
    @Binding var amountToTransfer: Amount       // does still have the wrong currency
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var shouldReloadBalances: Int = 0
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var currencyName: String = UNKNOWN
    @State private var currencySymbol: String = UNKNOWN
    @State private var didDelete: Bool = false
    @State private var disabled: Bool = false
    @State private var purge: Bool = false

    func amountAvailable(_ exchange: Exchange?, currency: String?) -> Amount? {
        if let exchange {
            for balance in balances {
                if let baseUrl = balance.scopeInfo.url {
                    if baseUrl == exchange.exchangeBaseUrl {
                        return balance.available
                    }
                } else if let currency {
                    if currency == balance.scopeInfo.currency {
                        return balance.available
                    }
                }
            }
        }
        return nil
    }

    private func deleteExchange() {
        disabled = true     // don't try this more than once
        Task { // runs on MainActor
            if let _ = try? await model.deleteExchange(url: exchange.exchangeBaseUrl, purge: purge) {
                symLog.log("deleted \(baseUrl.trimURL())")
                didDelete = true             // change button text
            } else {
                purge = true
                disabled = false
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
//        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scopeInfo = exchange.scopeInfo
        let currency = scopeInfo.currency
//        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
//        let currencyName = currencyInfo.scope.currency
        Section {
//            ForEach(exchanges) { exchange in
                ExchangeRowView(stack: stack.push(),
                         currencyInfo: $currencyInfo,
                             exchange: exchange,
                      amountAvailable: amountAvailable(exchange, currency: currency),
//                          depositIBAN: $depositIBAN,
//                        accountHolder: $accountHolder,
                             currency: currencyName,        // TODO: (balance.available) amount.isZero to disable Deposit-button
                     amountToTransfer: $amountToTransfer)   // does still have the wrong currency
                .listRowSeparator(.hidden)
//            }
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
            }

            let buttonTitle = String(localized: "Exchange.Delete", defaultValue: "Delete Payment Provider", comment: "Action button")
            WarningButton(warningText: String(localized: "Are you sure you want to delete this payment provider?"),
                          buttonTitle: buttonTitle,
                           buttonIcon: "trash",
                                 role: .destructive,
                             disabled: $disabled,
                               action: deleteExchange)
        } header: {
            BarGraphHeader(stack: stack.push(),
                       scopeInfo: scopeInfo,
                    currencyName: $currencyName,
                  currencySymbol: $currencySymbol,
            shouldReloadBalances: $shouldReloadBalances)
        }
        .task(id: controller.currencyTicker) {
            symLog.log("task \(didDelete ? 1 : 0)")
            currencyInfo = controller.info(for: currency, controller.currencyTicker)
            currencyName = currencyInfo.scope.currency
            currencySymbol = currencyInfo.altUnitSymbol ?? currencyName
        }
    }
}
// MARK: -
#if false   // model crashes
fileprivate struct ExchangeSection_Previews: PreviewProvider {
fileprivate struct ExchangeRow_Container : View {
    @State private var previewBalances: [Balance] = []
    @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 1234)
    @State private var depositIBAN = "DE1234567890"
    @State private var accountHolder = "Marc Stibane"

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
    var body: some View {
        let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
        let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                       scopeInfo: scopeInfo,
                                       paytoUris: [],
                                       tosStatus: .pending,
                             exchangeEntryStatus: .preset,
                            exchangeUpdateStatus: .initial,
                           ageRestrictionOptions: [12,16])
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                       scopeInfo: scopeInfo,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        ExchangeSectionView(stack: CallStack("Preview"), 
                         balances: $previewBalances,
//                        scopeInfo: scopeInfo,
                         exchange: exchange1,
//                        exchanges: [exchange1, exchange2],
//                      depositIBAN: $depositIBAN,
//                    accountHolder: $accountHolder,
                 amountToTransfer: $amountToPreview)
    }
}

    static var previews: some View {
        List {
            ExchangeRow_Container()
        }
    }
}
#endif
