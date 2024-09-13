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

// Will be called when a withdraw-exchange QR was scanned
struct WithdrawExchangeV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var balances: [Balance]
    @Binding var selectedBalance: Balance?
    var url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @State private var amountToTransfer = Amount.zero(currency: "")
    @State private var exchange: Exchange? = nil
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)

    let navTitle = String(localized: "Checking Link")

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let exchange {
            let currency = exchange.scopeInfo.currency
            Group {
                ManualWithdraw(stack: stack.push(),
                            balances: balances,
                     selectedBalance: $selectedBalance,
//                      currencyInfo: $currencyInfo,
                             isSheet: true,
                           scopeInfo: exchange.scopeInfo,
                            exchange: $exchange,
                    amountToTransfer: $amountToTransfer)
            }
            .task(id: controller.currencyTicker) {
                currencyInfo = controller.info(for: currency, controller.currencyTicker)
//                currencyName = currencyInfo.scope.currency
            }
        } else {
            LoadingView(scopeInfo: nil, message: "No exchangeBaseUrl!")
            .task {
                if exchange == nil {
                    symLog.log(".task")
                    if let withdrawExchange = try? await model.loadWithdrawalExchangeForUriM(url.absoluteString) {
                        let baseUrl = withdrawExchange.exchangeBaseUrl
                        symLog.log("getExchangeByUrl(\(baseUrl))")
                        if let exc = try? await model.getExchangeByUrl(url: baseUrl) {
                            // let the controller collect CurrencyInfo from this formerly unknown exchange
                            let _ = try? await controller.getInfo(from: baseUrl, model: model)
                            if let amount = withdrawExchange.amount {
                                amountToTransfer = amount
                            } else {
                                let currency = exc.scopeInfo.currency
                                amountToTransfer.setCurrency(currency)
                                // is already Amount.zero(currency: "")
                            }
                            exchange = exc
                        } else {
                            exchange = nil
                        }
                    }
                }
            }
        }
    }
}
