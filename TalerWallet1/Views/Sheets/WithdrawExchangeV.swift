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
    @Binding var selectedBalance: Balance?
    var url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)
    @State private var exchange: Exchange? = nil
    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)

    let navTitle = String(localized: "Checking Link")

    @MainActor
    private func viewDidLoad() async {
        if exchange == nil {
            symLog.log(".task")
            if let withdrawExchange = try? await model.loadWithdrawalExchangeForUri(url.absoluteString) {
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
                        // is already Amount.zero()
                    }
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
                     selectedBalance: $selectedBalance,
                      amountLastUsed: $amountLastUsed,
                             isSheet: true)
            }
            .task(id: controller.currencyTicker) {
                currencyInfo = controller.info(for: scopeInfo, controller.currencyTicker)
            }
        } else {
            let message = String(localized: "No payment service...", comment: "loading")
            LoadingView(scopeInfo: nil, message: message)
                .task { await viewDidLoad() }
        }
    }
}
