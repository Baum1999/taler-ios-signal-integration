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

// Called either when scanning a QR code or tapping the provided link, both from the bank's website.
// We show the user the manual withdrawal details in a sheet - but first the ToS must be accepted.
struct WithdrawExchangeScan: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let selectedBalance: Balance?
    var url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var exchange: Exchange? = nil
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)

    @MainActor
    private func viewDidLoad() async {
        if exchange == nil {
            symLog.log(".task")
            if let withdrawExchange = try? await model.prepareWithdrawExchange(url.trimmedString) {
                let baseUrl = withdrawExchange.exchangeBaseUrl
                controller.updateBase(baseUrl, forSaved: url)
                symLog.log("getExchangeByUrl(\(baseUrl))")
                if let exc = try? await model.getExchangeByUrl(url: baseUrl) {
                    // let the controller collect CurrencyInfo from this formerly unknown exchange
                    let _ = try? await controller.getInfo(from: baseUrl, model: model)
                    if let amount = withdrawExchange.amount {
                        amountToTransfer = amount
                    } else {
                        let currency = exc.scopeInfo.currency
                        amountToTransfer.setCurrency(currency)
                        // is already Amount.zero()
                    }
                    amountLastUsed.setCurrency(amountToTransfer.currencyStr)
                    exchange = exc
                } else {
                    exchange = nil
                }
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let exchange {
            let scopeInfo = exchange.scopeInfo
            Group {
                ManualWithdraw(stack: stack.push(),
                                 url: url,
                     selectedBalance: selectedBalance,
                      amountLastUsed: $amountLastUsed,
                    amountToTransfer: $amountToTransfer,
                            exchange: exchange,                     // only for withdraw-exchange
                 maySwitchCurrencies: false,
                             isSheet: true)
            }
            .task(id: controller.currencyTicker) {
                currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
            }
        } else {
            let message = String(localized: "Contacting payment service...", comment: "loading")
            LoadingView(stack: stack.push(), scopeInfo: nil, message: message)
                .task { await viewDidLoad() }
        }
    }
}
