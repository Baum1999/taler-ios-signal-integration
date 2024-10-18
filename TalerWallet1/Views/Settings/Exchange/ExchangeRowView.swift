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

struct ExchangeRowView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    let exchange: Exchange
    @Binding var amountToTransfer: Amount       // does still have the wrong currency

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
        let delay: UInt = 0     // set to 5 to test delayed currency information
#else
        let delay: UInt = 0
#endif
        let baseURL = exchange.exchangeBaseUrl
        let showToS = LazyView {
            WithdrawTOSView(stack: stack.push(),
                  exchangeBaseUrl: baseURL,
                           viewID: VIEW_WITHDRAW_TOS,
                     acceptAction: nil)         // pop back to here
        }
        Group {
            NavigationLink(destination: showToS) {
                VStack(alignment: .leading) {
                    Text(baseURL.trimURL)
                        .talerFont(.headline)
                    if !minimalistic {
                        Text("Terms of Service")  // VIEW_WITHDRAW_TOS
                            .talerFont(.body)
                    }
                }
            }
            .listRowSeparator(.hidden)

        }
    }
}
// MARK: -
#if DEBUG
fileprivate struct ExchangeRow_Previews: PreviewProvider {
    @MainActor
    struct BindingViewContainer : View {
        @State private var amountToPreview = Amount(currency: LONGCURRENCY, cent: 1234)
        @State private var depositIBAN = "DE1234567890"
        @State private var accountHolder = "Marc Stibane"
        @State private var currencyInfoL: CurrencyInfo = CurrencyInfo.zero(LONGCURRENCY)

//    let amount = Amount(currency: LONGCURRENCY, cent: 123456)
        var body: some View {
            let scopeInfo = ScopeInfo(type: .exchange, currency: LONGCURRENCY)
            let exchange1 = Exchange(exchangeBaseUrl: ARS_AGE_EXCHANGE,
                                           masterPub: "masterPub",
                                           scopeInfo: scopeInfo,
                                           paytoUris: [],
                                           tosStatus: .pending,
                                 exchangeEntryStatus: .preset,
                                exchangeUpdateStatus: .initial,
                               ageRestrictionOptions: [12,16])
            let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                           masterPub: "masterPub",
                                           scopeInfo: scopeInfo,
                                           paytoUris: [],
                                           tosStatus: .proposed,
                                 exchangeEntryStatus: .ephemeral,
                                exchangeUpdateStatus: .ready,
                               ageRestrictionOptions: [])
            ExchangeRowView(stack: CallStack("Preview"),
                     currencyInfo: $currencyInfoL,
                         exchange: exchange1,
//                      depositIBAN: $depositIBAN,
//                    accountHolder: $accountHolder,
                 amountToTransfer: $amountToPreview)
        }
    }

    @MainActor
    static var previews: some View {
        List {
            BindingViewContainer()
        }
    }
}
#endif
